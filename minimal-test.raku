use v6;

class Nats {
    has $.socket-class = IO::Socket::Async;
    has @.servers = ["nats://nats_js:4222"];  # Use the container name
    has Promise $!conn .= new;
    has Supplier $!supplier .= new;
    has Supply $.supply = $!supplier.Supply;
    has %!subs;
    has Bool $!DEBUG = True;

    method !pick-server {
        @!servers.pick;
    }

    method !get-supply {
        my $server = self!pick-server;
        say "Connecting to $server";
        my ($host, $port) = $server.subst("nats://", "").split(":");
        $!socket-class.connect($host, $port.Int);
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

    method handle-input {
        $!conn.result.Supply.tap: -> $line {
            say ">> $line";
            if $line.starts-with("INFO ") {
                self!print: "CONNECT { %( verbose => False, pedantic => False, lang => "raku", version => "0.0.1", protocol => 1 ).perl }";
            }
            elsif $line.starts-with("PING") {
                self!print: "PONG";
            }
        }
    }

    method subscribe($subject, :$queue, :$sid = (^10000).pick) {
        self!print: "SUB $subject { $queue // "" } $sid";
        $sid;
    }

    method publish($subject, $payload = "", :$reply-to) {
        self!print: "PUB $subject { $reply-to // "" } { $payload.chars }\r\n$payload";
    }

    method !print(*@msg) {
        say "<< { @msg.join(" ") }";
        $!conn.result.print: "{ @msg.join(" ") }\r\n";
    }
}

# Simplest test
my $nats = Nats.new;

my $p = start {
    react whenever $nats.start {
        say "Connected to NATS server!";
        
        my $sid = $nats.subscribe("test.topic");
        $nats.publish("test.topic", "Hello from Raku!");
        
        whenever Promise.in(5) {
            say "Exiting after timeout";
            exit 0;
        }
    }
}

await Promise.anyof($p, Promise.in(10));