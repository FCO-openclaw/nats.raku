=begin pod

=head1 NAME

Nats::JetStream::Subscriptions - DSL for JetStream consumers with routing

=head1 SYNOPSIS

=begin code
use Nats::JetStream::Subscriptions;

my $js-subs = js-subscriptions {
    # Simple consumer
    consume "ORDERS", "processor", -> $msg {
        say "Processing order: ", $msg.payload;
        $msg.ack;
    }
    
    # With filter subject
    consume "ORDERS", "big-orders", 
        filter-subject => "orders.large.*",
        -> $msg {
        $msg.ack;
    }
    
    # With batch size
    consume "EVENTS", "batch-processor",
        batch => 100,
        -> $msg {
        say $msg.payload;
        $msg.ack;
    }
}

# Use with Nats::JetStream::Client
my $client = Nats::JetStream::Client.new(
    js => $js,
    subscriptions => $js-subs
);
$client.start;
=end code

=head1 DESCRIPTION

C<Nats::JetStream::Subscriptions> provides a DSL for defining JetStream
consumers in a declarative way.

=head1 EXPORTED SUBROUTINES

=head2 js-subscriptions

Creates a new C<Nats::JetStream::Subscriptions> object.

=begin code
my $js-subs = js-subscriptions {
    consume "STREAM", "CONSUMER", -> $msg { ... }
}
=end code

=head2 consume

Defines a JetStream consumer subscription.

=begin code
# Basic consumer
consume "ORDERS", "processor", -> $msg {
    $msg.ack;
}

# With options
consume "EVENTS", "handler",
    filter-subject => "events.user.*",
    batch => 100,
    -> $msg {
    $msg.ack;
}
=end code

B<Parameters:>
=item B<Stream name>: First positional - stream name
=item B<Consumer name>: Second positional - consumer name
=item B<filter-subject>: Optional named - subject filter pattern
=item B<batch>: Optional named - batch size (default: 1)
=item B<expires>: Optional named - timeout in ms
=item B<Block>: Final positional - handler block receiving $msg

=head1 SEE ALSO

=item L<Nats::JetStream::Client> - Client that uses these subscriptions
=item L<Nats::JetStream> - Core JetStream API

=head1 AUTHOR

Fernando Correa de Oliveira <fco@cpan.org>

=head1 LICENSE

Artistic-2.0

=end pod

use Nats::JetStream;
use JSON::Fast;

unit class Nats::JetStream::Subscriptions;

has @.subscriptions;

# Export subs for DSL
sub consume(Str $stream, Str $consumer, &block, *%opts) is export {
    my %config = (
        stream => $stream,
        consumer => $consumer,
        batch => %opts<batch> // 1,
        block => &block,
    );
    %config<filter-subject> = %opts<filter-subject> if %opts<filter-subject>;
    %config<expires> = %opts<expires> if %opts<expires>;
    
    @*JS-SUBSCRIPTIONS.push: %config;
}

sub js-subscriptions(&block) is export {
    my @*JS-SUBSCRIPTIONS;
    block;
    Nats::JetStream::Subscriptions.new: :subscriptions(@*JS-SUBSCRIPTIONS)
}
