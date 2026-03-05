=begin pod

=head1 NAME

Nats - A Raku client for NATS.io messaging system

=head1 DOCUMENTATION

Full API documentation is available at: L<https://fco-openclaw.github.io/nats.raku/>

=head1 SYNOPSIS

=begin code
# Simple reactive style
use Nats;

given Nats.new {
    react whenever .start {
        whenever .subscribe("bla.ble.bli").supply {
            say "Received: { .payload }";
        }
    }
}
=end code

=begin code
# Structured style with routing
use Nats::Client;
use Nats::Subscriptions;

my $subscriptions = subscriptions {
    subscribe -> "bla", $ble, "bli" {
        say "ble: $ble";
        say "payload: ", message.payload;
        message.?reply-json: { :status<ok>, :$ble, :payload(message.payload) };
    }
}

my $server = Nats::Client.new: :$subscriptions;
$server.start;
react whenever signal(SIGINT) { $server.stop; exit }
=end code

=begin code
# Object-oriented style with JetStream
use Nats;
use Nats::JetStream;

my $nats = Nats.new(servers => ["nats://localhost:4222"]);
await $nats.start;

# Subscribe to messages
my $sub = $nats.subscribe("hello.>");
$sub.supply.tap(-> $msg {
    say "Received: $msg.payload() on $msg.subject()";
});

# Publish messages
$nats.publish("hello.world", "Hello from Raku!");

# Request/Reply
my $response = await $nats.request("service.status", "ping").head;

# JetStream
my $js = Nats::JetStream.new(nats => $nats);
$js.add-stream("ORDERS", subjects => ["orders.>"]);
=end code

=head1 DESCRIPTION

Nats is a Raku client for the NATS.io messaging system, a lightweight,
high-performance cloud native messaging system. This module provides:

=item Core NATS protocol support (publish, subscribe, request/reply)
=item JetStream support for persistent messaging
=item Authentication (Token, Username/Password, JWT/NKeys)
=item Asynchronous messaging via Supplies
=item Two usage styles: simple reactive or structured with routing

=head1 USAGE STYLES

=head2 Simple Reactive Style

Use the C<Nats> class directly for a simple, reactive approach:

=begin code
use Nats;

my $nats = Nats.new;
react whenever $nats.start {
    whenever $nats.subscribe("orders.>").supply -> $msg {
        say "Received order: $msg.payload()";
    }
}
=end code

=head2 Structured Style with Nats::Client

Use C<Nats::Client> and C<Nats::Subscriptions> for a more structured,
route-based approach similar to web frameworks:

=begin code
use Nats::Client;
use Nats::Subscriptions;

my $subscriptions = subscriptions {
    # Route: "users.<id>.orders"
    subscribe -> "users", $user-id, "orders" {
        say "User $user-id created an order";
        say "Payload: ", message.payload;
        
        # Reply with JSON
        message.?reply-json: {
            :status<created>,
            :user-id($user-id),
            :order-id(12345)
        };
    }
    
    # Route with wildcards
    subscribe -> "events", * {
        say "Event received: ", message.payload;
    }
}

my $server = Nats::Client.new: :$subscriptions;
$server.start;

# Graceful shutdown
react whenever signal(SIGINT) {
    $server.stop;
    exit;
}
=end code

B<Route Patterns:>
=item Literal: C<"users"> matches exactly "users"
=item Capture: C<$user-id> captures that position
=item Wildcard: C<*> captures any single token

=head1 ATTRIBUTES

=head2 socket-class

The socket class to use for connections. Defaults to C<IO::Socket::Async>.

=head2 servers

Array of NATS server URLs to connect to. Defaults to C<nats://127.0.0.1:4222>
or the C<NATS_URL> environment variable.

=head2 supply

A Supply that emits L<Nats::Message> objects for incoming messages.

=head1 METHODS

=head2 new

Creates a new NATS connection.

=begin code
# Basic
my $nats = Nats.new;

# With multiple servers
my $nats = Nats.new(servers => ["nats://server1:4222", "nats://server2:4222"]);

# With authentication
my $nats = Nats.new(
    servers => ["nats://localhost:4222"],
    token => "my-secret-token"
);

# With JWT auth
my $nats = Nats.new(
    jwt-path => "/path/to/jwt.creds",
    nkey-seed => "SU..."
);
=end code

=head2 start

Starts the connection to the NATS server.

=begin code
my $nats = Nats.new;
await $nats.start;
=end code

=head2 stop

Closes the connection.

=begin code
$nats.stop;
=end code

=head2 subscribe

Subscribes to a subject pattern.

=begin code
# Simple subscription
my $sub = $nats.subscribe("foo.>");
$sub.supply.tap(-> $msg { say $msg.payload() });

# With queue group
my $sub = $nats.subscribe("tasks", :queue("workers"));

# With max messages
my $sub = $nats.subscribe("notifications", :max-messages(10));
=end code

=head2 publish

Publishes a message to a subject.

=begin code
$nats.publish("orders.created", "Order #12345");

# With reply-to
$nats.publish("service.request", "data", :reply-to("_INBOX.123"));
=end code

=head2 request

Sends a request and returns a Supply with responses.

=begin code
my $response = await $nats.request("service.echo", "hello").head;
say $response.payload();

# Request with multiple responses
$nats.request("service.status", "ping", :max-messages(5)).tap(-> $msg {
    say "Response from: $msg.subject()";
});
=end code

=head2 ping

Sends a PING to the server.

=begin code
$nats.ping;
=end code

=head2 stream

Creates a L<Nats::Stream> object.

=begin code
my $stream = $nats.stream("events", "events.created", "events.updated");
=end code

=head1 ENVIRONMENT

=item NATS_URL - Default NATS server URL
=item NATS_DEBUG - Enable debug output

=head1 SEE ALSO

=item L<Nats::JetStream> - JetStream support
=item L<Nats::Message> - Message objects
=item L<Nats::Subscription> - Subscriptions

=head1 AUTHOR

Fernando Correa de Oliveira <fco@cpan.org>

=head1 LICENSE

Artistic-2.0

=end pod

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

# TLS configuration
has Str $.tls-ca-file;
has Str $.tls-cert-file;
has Str $.tls-key-file;
has Bool $.tls-verify = True;

# Authentication
has Str $.jwt;
has Str $.nkey-seed;
has Str $.creds-file;
has Str $.token;
has Str $.user;
has Str $.password;

# Connection options
has Bool $.reconnect = True;
has Int $.max-reconnect = 10;
has Rat $.reconnect-delay = 1.0;
has Rat $.reconnect-delay-max = 60.0;
has Rat $.reconnect-jitter = 0.5;
has Rat $.connect-timeout = 5.0;
has Int $.ping-interval = 120;
has Int $.max-pings-out = 2;

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
        create-auth(
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
    
    self.bless(:$auth, |%args)
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

method drain(:$timeout = 30) {
    # Graceful shutdown - process pending messages
    # In a real implementation, this would:
    # 1. Stop accepting new subscriptions
    # 2. Wait for pending messages to be processed
    # 3. Close connection
    
    # For now, just close the connection
    self.stop;
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
                            %!server-info = $cmd.data;
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