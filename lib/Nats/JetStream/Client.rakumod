=begin pod

=head1 NAME

Nats::JetStream::Client - Structured JetStream client with consumer routing

=head1 SYNOPSIS

=begin code
use Nats::JetStream::Client;
use Nats::JetStream::Subscriptions;

# Define JetStream consumers with routing
my $js-subs = js-subscriptions {
    consume "ORDERS", "processor", -> $msg {
        say "Processing order: ", $msg.payload;
        $msg.ack;
    }
    
    consume "EVENTS", "event-handler",
        -> $msg {
        $msg.ack;
    }, filter-subject => "events.user.*"
}

# Create and start client
my $client = Nats::JetStream::Client.new(
    js => $js,
    subscriptions => $js-subs
);

$client.start;

# Graceful shutdown
react whenever signal(SIGINT) {
    $client.stop;
    exit;
}
=end code

=head1 DESCRIPTION

C<Nats::JetStream::Client> provides a structured way to work with JetStream
consumers using a routing DSL. This is the JetStream equivalent of 
L<Nats::Client>, allowing you to define consumer handlers in a clean,
declarative way.

=head1 ATTRIBUTES

=head2 js

The underlying L<Nats::JetStream> instance. Required.

=head2 subscriptions

Required. A L<Nats::JetStream::Subscriptions> object containing the consumer
definitions.

=head2 auto-create-streams

Boolean. If True (default), automatically creates streams if they don't exist.
Set to False to require manual stream creation.

=head2 auto-create-consumers

Boolean. If True (default), automatically creates consumers if they don't exist.
Set to False to require manual consumer creation.

=head1 METHODS

=head2 new

Creates a new structured JetStream client.

=begin code
my $client = Nats::JetStream::Client.new(
    js => $js,
    subscriptions => $js-subs
);
=end code

=head2 start

Starts all consumer subscriptions.

=begin code
$client.start;
=end code

=head2 stop

Stops all consumer subscriptions gracefully.

=begin code
$client.stop;
=end code

=head2 is-running

Returns True if the client is currently running.

=begin code
while $client.is-running {
    sleep 1;
}
=end code

=head1 EXAMPLES

=head2 E-commerce Order Processing

=begin code
use Nats::JetStream::Client;
use Nats::JetStream::Subscriptions;
use JSON::Fast;

my $js-subs = js-subscriptions {
    # New orders
    consume "ORDERS", "new-orders", -> $msg {
        my $order = from-json($msg.payload);
        validate($order);
        $msg.ack;
    }
    
    # VIP orders
    consume "ORDERS", "vip-orders", -> $msg {
        my $order = from-json($msg.payload);
        notify-vip($order);
        $msg.ack;
    }, filter-subject => "orders.vip.*"
    
    # Batch processing
    consume "ANALYTICS", "events", -> $msg {
        process-event($msg.payload);
        $msg.ack;
    }, batch => 100
}

my $client = Nats::JetStream::Client.new(
    js => $js,
    subscriptions => $js-subs
);

$client.start;

react whenever signal(SIGINT) {
    $client.stop;
    exit;
}
=end code

=head1 SEE ALSO

=item L<Nats::JetStream::Subscriptions> - Consumer definition DSL
=item L<Nats::JetStream> - Core JetStream API
=item L<Nats::Client> - Regular NATS structured client

=head1 AUTHOR

Fernando Correa de Oliveira <fco@cpan.org>

=head1 LICENSE

Artistic-2.0

=end pod

use Nats::JetStream;
use Nats::JetStream::Subscriptions;

unit class Nats::JetStream::Client;

has Nats::JetStream $.js is required;
has Nats::JetStream::Subscriptions $.subscriptions is required;
has Bool $.auto-create-streams = True;
has Bool $.auto-create-consumers = True;
has Bool $!running = False;
has @!active-subscriptions;

method start {
    return if $!running;
    
    # Process each subscription configuration
    for $!subscriptions.subscriptions -> %config {
        my $stream = %config<stream>;
        my $consumer = %config<consumer>;
        my $batch = %config<batch> // 1;
        my &block = %config<block>;
        
        # Create stream if needed
        if $!auto-create-streams {
            try {
                $!js.stream-info($stream);
                CATCH {
                    default {
                        $!js.add-stream($stream, subjects => [$stream ~ ".>"]);
                    }
                }
            }
        }
        
        # Create consumer if needed
        if $!auto-create-consumers {
            try {
                $!js.consumer-info($stream, $consumer);
                CATCH {
                    default {
                        my %consumer-config = ( ack_policy => "explicit" );
                        %consumer-config<filter_subject> = %config<filter-subject> 
                            if %config<filter-subject>;
                        $!js.add-consumer($stream, $consumer, |%consumer-config);
                    }
                }
            }
        }
        
        # Start fetching messages
        my $sub = $!js.fetch(
            $stream, 
            $consumer, 
            batch => $batch,
            |(:expires(%config<expires>) if %config<expires>)
        );
        
        # Tap into the supply
        my $tap = $sub.supply.tap(-> $msg {
            try {
                block($msg);
                CATCH {
                    default {
                        # Default error handling - nak the message
                        $msg.nak if $msg.^can('nak');
                    }
                }
            }
        });
        
        @!active-subscriptions.push: $tap;
    }
    
    $!running = True;
}

method stop {
    return unless $!running;
    
    for @!active-subscriptions -> $tap {
        $tap.close if $tap.^can('close');
    }
    @!active-subscriptions = ();
    
    $!running = False;
}

method is-running {
    $!running;
}
