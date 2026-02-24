unit class Nats;
use URL;
use JSON::Fast;
use Nats::Error;
use Nats::Grammar;
use Nats::Actions;
use Nats::Data;
use Nats::Message;
use Nats::Subscription;
use Nats::JetStream;
use Nats::Auth;

has $.socket-class       = IO::Socket::Async;
has %!subs;
has URL()    @.servers   = self.default-url;
has Promise  $!conn     .= new;
has Supplier $!supplier .= new;
has Supply   $.supply    = $!supplier.Supply;
has Nats::Auth::Base $.auth = Nats::Auth::Base.new;
has %!server-info;  # To store server info, including nonce for JWT auth

has Bool() $!DEBUG = %*ENV<NATS_DEBUG>;

method default-url { URL.new: %*ENV<NATS_URL> // "nats://127.0.0.1:4222" }

# Constructor with auth support
multi method new(
    :$token, 
    :$username, 
    :$password, 
    :$jwt-path, 
    :$nkey-path,
    :$nkey-seed,
    *%args
) {
    # Create auth object if any auth params are provided
    my $auth = do if $token.defined || $username.defined || $password.defined || 
                   $jwt-path.defined || $nkey-path.defined || $nkey-seed.defined {
        Nats::Auth::create-auth(
            :$token, 
            :$username, 
            :$password, 
            :$jwt-path, 
            :$nkey-path,
            :$nkey-seed
        )
    } else {
        Nats::Auth::Base.new
    }
    
    self.new(:$auth, |%args)
}

method !pick-server {
    @!servers.pick;
}

method !get-supply {
    with self!pick-server {
        self!debug("connecting to { .Str }");
        $!socket-class.connect(.hostname, .port)
    }
}

method start {
    my Promise $start .= new;
    self!get-supply.then: -> $conn {
        $!conn.keep: $conn.result;
        with $start {
            .keep: self;
            $start = Nil;
        }
        self.handle-input;
    }
    $!conn.then: -> $ { self }
}

method stop {
    $!conn.result.close;
}

method handle-input {
    $!conn.result.Supply.tap: -> $line {
        self!in($line);
        my @cmds = Nats::Grammar.parse($line, :actions(Nats::Actions.new: :nats(self))).ast;
        for @cmds -> $cmd {
            given $cmd {
                when Nats::Data {
                    given .type {
                        when "ok"   {                    }
                        when "err"  { die $cmd.data      }
                        when "ping" { self!print: "PONG" }
                        when "pong" {                    }
                        when "info" { 
                            # Store server info for auth and other purposes
                            %!server-info = from-json($cmd.data);
                            # After receiving server info, we can send the CONNECT
                            self.connect;
                        }
                    }
                }
                when Nats::Message { $!supplier.emit: $_ }
            }
        }
    }
}

method connect {
    my %connect-params = %(
        verbose => False,
        pedantic => False,
        lang => "raku",
        version => "0.0.1",
        protocol => 1,
    );
    
    # Check if this is JWT auth and we need to handle nonce
    if $!auth.^name eq "Nats::Auth::JWT" && (%!server-info<nonce>:exists) {
        # For JWT auth with nonce, we need to add the signature
        my $nonce = %!server-info<nonce>;
        %connect-params = |%connect-params, |$!auth.with-signature($nonce);
    } 
    # Otherwise, just add the standard auth params
    elsif $!auth {
        %connect-params = |%connect-params, |$!auth.connect-params();
    }
    
    self!print: "CONNECT", to-json(:!pretty, %connect-params);
}

method ping {
    self!print: "PING"
}

method subscribe(Str $subject, Str :$queue, UInt :$max-messages) {
    my $sub = Nats::Subscription.new:
        :$subject,
        |(:$queue with $queue),
        |(:$max-messages with $max-messages),
        :nats(self),
    ;
    $sub.messages-from-supply: $!supply;
    %!subs{$sub.sid} = $sub;
    self!print: "SUB", $subject, $queue // Empty, $sub.sid;
    $sub.unsubscribe: :$max-messages if $max-messages;
    $sub
}

my @chars = |("a" .. "z"), |("A" .. "Z"), |("0" .. "9"), "_";

method gen-inbox { self!gen-inbox }
method !gen-inbox {
    my $inbox = "_INBOX." ~ (@chars.pick xx 32).join;
    $inbox
}

method request(
    Str   $subject,
    Str() $payload?,
    Str   :$reply-to     = self!gen-inbox,
    UInt  :$max-messages = 1,
) {
    my $sub = self.subscribe: $reply-to, :$max-messages;
    self.publish: $subject, |(.Str with $payload), :$reply-to;
    $sub.supply.head: $max-messages;
}

multi method unsubscribe(Nats::Subscription $sub, UInt :$max-messages) {
    self.unsubscribe: $sub.sid, |(:$max-messages with $max-messages)
}

multi method unsubscribe(UInt $sid, UInt :$max-messages) {
    self!print: "UNSUB", $sid, $max-messages // Empty;
    %!subs{$sid}:delete;
}

method publish(Str $subject, Str() $payload = "", Str :$reply-to) {
    self!print: "PUB", $subject, $reply-to // Empty, "{ $payload.chars }\r\n$payload";
}

method stream($name, *@subjects, |c) {
    Nats::Stream.new: :nats(self), :$name, |(:@subjects if @subjects), |c
}

method !in(|c) {
    self!debug(">>", |c)
}

method !out(|c) {
    self!debug("<<", |c)
}

method !debug(*@msg) {
    note @msg.map(*.gist).join: " " if $!DEBUG
}

method !print(*@msg) {
    self!out(|@msg);
    (await $!conn ).print: "{ @msg.join: " " }\r\n";
}