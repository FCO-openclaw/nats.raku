=begin pod

=head1 NAME

Nats::Client - Structured NATS client with routing support

=head1 SYNOPSIS

=begin code
use Nats::Client;
use Nats::Subscriptions;

# Define subscriptions with routing
my $subscriptions = subscriptions {
    subscribe -> "users", $id, "orders" {
        say "User $id ordered: ", message.payload;
        message.?reply: "Order confirmed";
    }
    
    subscribe -> "events", * {
        say "Event: ", message.payload;
    }
}

# Create and start client
my $client = Nats::Client.new: :$subscriptions;
$client.start;

# Graceful shutdown
react whenever signal(SIGINT) {
    $client.stop;
    exit;
}
=end code

=head1 DESCRIPTION

C<Nats::Client> provides a structured way to work with NATS using a routing DSL
similar to web frameworks. Instead of manually subscribing and handling messages,
you define routes with patterns that capture parts of the subject.

This is ideal for building services that need to handle multiple message types
in a clean, organized way.

=head1 ATTRIBUTES

=head2 nats-class

The class to use for the underlying NATS connection. Defaults to C<Nats>.

=head2 servers

Array of NATS server URLs. Defaults to the NATS default URL.

=head2 nats

The underlying L<Nats> instance.

=head2 subscriptions

Required. A L<Nats::Subscriptions> object containing the route definitions.

=head1 METHODS

=head2 new

Creates a new client with subscriptions.

=begin code
my $client = Nats::Client.new(
    subscriptions => $subscriptions,
    servers => ["nats://localhost:4222"]
);
=end code

=head2 start

Starts the client and all subscriptions.

=begin code
$client.start;
=end code

=head2 stop

Stops the client and closes the connection.

=begin code
$client.stop;
=end code

=head1 ROUTE PATTERNS

Route patterns support three types of segments:

=item B<Literal>: C<"users"> - matches exactly "users"
=item B<Capture>: C<$id> - captures that position into the variable
=item B<Wildcard>: C<*> - matches any single token

B<Examples:>

=begin code
# Pattern: "api.users.<id>.orders"
# Matches: "api.users.123.orders"
# Captures: $id = "123"
subscribe -> "api", "users", $id, "orders" {
    say "Orders for user $id";
}

# Pattern: "events.*"
# Matches: "events.created", "events.deleted", etc.
subscribe -> "events", * {
    say "Event received";
}
=end code

=head1 SPECIAL VARIABLES

Inside a subscribe block, these variables are available:

=item B<message> - The L<Nats::Message> object
=item B<.payload()> - Shortcut for C<message.payload()>
=item B<.subject()> - Shortcut for C<message.subject()>

=head1 REPLYING TO MESSAGES

=begin code
subscribe -> "requests", "greeting" {
    # Simple text reply
    message.?reply: "Hello!";
    
    # JSON reply
    message.?reply-json: { :status<ok>, :message<Hello> };
}
=end code

=head1 SEE ALSO

=item L<Nats> - Simple reactive client
=item L<Nats::Subscriptions> - Route definition DSL
=item L<Nats::Message> - Message object

=head1 AUTHOR

Fernando Correa de Oliveira <fco@cpan.org>

=head1 LICENSE

Artistic-2.0

=end pod

use Nats;
unit class Nats::Client;

has       $.nats-class    = Nats;
has Str() @.servers       = Nats.default-url;
has Nats  $.nats          = $!nats-class.new: :@!servers;
has       $.subscriptions is required;

method start {
    await $!nats.start;

    for $!subscriptions.subscriptions -> $sub {
        given $sub {
            # JetStream subscription (hash config)
            when Hash {
                self!start-jetstream-subscription($_);
            }
            # Regular NATS subscription (callable)
            when Callable {
                $sub($!nats);
            }
        }
    }
}

method !start-jetstream-subscription(%config) {
    use Nats::JetStream;
    
    my $js = Nats::JetStream.new(nats => $!nats);
    my $stream = %config<stream>;
    my $consumer = %config<consumer>;
    my $batch = %config<batch> // 1;
    my &block = %config<block>;
    
    # Ensure stream exists
    {
        $js.stream-info($stream);
        CATCH {
            default {
                # Create stream with default subjects
                $js.add-stream($stream, subjects => [$stream ~ ".>"]);
            }
        }
    }

    # Ensure consumer exists
    {
        $js.consumer-info($stream, $consumer);
        CATCH {
            default {
                my %consumer-config = (ack_policy => "explicit");
                %consumer-config<filter_subject> = %config<filter> if %config<filter>;
                $js.add-consumer($stream, $consumer, |%consumer-config);
            }
        }
    }

    # Start fetching
    my $subscription = $js.fetch($stream, $consumer, :$batch);
    $subscription.supply.tap(-> $msg {
        my $*MESSAGE = $msg;
        my $*JS-MESSAGES = [$msg];
        {
            # Extract subject parts and call block
            my @parts = $msg.subject.split('.');
            block(|@parts);
            CATCH {
                default {
                    # Default error handling
                    $msg.nak if $msg.^can('nak');
                }
            }
        }
    });
}

method stop {
    $!nats.stop;
}
