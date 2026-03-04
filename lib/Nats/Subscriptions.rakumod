=begin pod

=head1 NAME

Nats::Subscriptions - DSL for defining NATS subscription routes

=head1 SYNOPSIS

=begin code
use Nats::Subscriptions;

my $subscriptions = subscriptions {
    # Simple subscription
    subscribe -> "orders", "created" {
        say "New order: ", message.payload;
    }
    
    # With captured parameters
    subscribe -> "users", $user-id, "orders" {
        say "User $user-id ordered: ", message.payload;
    }
    
    # With wildcard
    subscribe -> "events", * {
        say "Event: ", message.payload;
    }
    
    # With queue group
    subscribe -> "tasks", :queue<workers> {
        say "Task: ", message.payload;
    }
    
    # With max messages limit
    subscribe -> "notifications", :max-messages(100) {
        say "Notification: ", message.payload;
    }

    # JetStream subscription (separate function with all options)
    js-subscribe -> $order-id {
        say "Processing order $order-id: ", message.payload;
        message.ack;
    }, 
    :stream<ORDERS>, 
    :consumer<processor>,
    :filter<orders.created.>;

    # JetStream with delivery policy
    js-subscribe -> $event {
        say "Event: ", message.payload;
        message.ack;
    },
    :stream<EVENTS>,
    :consumer<handler>,
    :deliver-policy<all>,  # all, last, new, by_start_sequence, by_start_time
    :batch(100);
}

# Use with Nats::Client - handles both NATS core and JetStream
my $client = Nats::Client.new: :$subscriptions;
$client.start;
=end code

=head1 DESCRIPTION

C<Nats::Subscriptions> provides a Domain Specific Language (DSL) for defining
NATS subscriptions in a declarative way. It allows you to define routes using
Raku's signature syntax, making it easy to capture parts of the subject and
handle different message patterns.

=head1 EXPORTED SUBROUTINES

=head2 subscriptions

Creates a new C<Nats::Subscriptions> object containing all the defined
subscription routes.

=begin code
my $subscriptions = subscriptions {
    subscribe -> "foo", "bar" { ... }
    subscribe -> "baz", * { ... }
}
=end code

=head2 subscribe

Defines a new subscription route.

=begin code
# Basic subscription
subscribe -> "subject", "pattern" {
    say message.payload;
}

# With queue group (load balancing)
subscribe -> "tasks", :queue<workers> {
    say message.payload;
}

# With max messages limit
subscribe -> "temp", :max-messages(10) {
    say message.payload;
}

# JetStream (persistent messaging)
subscribe -> "orders", $id, :stream<ORDERS>, :consumer<processor> {
    say "Order: $id";
    message.ack;
}

# JetStream with options
subscribe -> "events", :stream<EVENTS>, :consumer<handler>, :filter<events.*>, :batch(100) {
    message.ack;
}
=end code

=head2 js-subscribe

Defines a JetStream consumer subscription with full configuration options.
Unlike regular C<subscribe>, this creates a persistent JetStream consumer.

=begin code
# Basic JetStream subscription
js-subscribe -> $id {
    say "Processing: ", message.payload;
    message.ack;
}, :stream<ORDERS>;

# With named consumer and filter
js-subscribe -> $id {
    process-order(message.payload);
    message.ack;
}, 
:stream<ORDERS>, 
:consumer<processor>,
:filter<orders.vip.>;

# With delivery policy (start from beginning)
js-subscribe -> $event {
    say "Event: ", message.payload;
    message.ack;
},
:stream<EVENTS>,
:consumer<replay>,
:deliver-policy<all>;  # all, last, new, by_start_sequence

# With batch processing
js-subscribe -> $log {
    bulk-process(messages);
    .ack for messages;
},
:stream<LOGS>,
:consumer<batcher>,
:batch(500),
:expires(5000);

# Replay from specific sequence
js-subscribe -> $msg {
    message.ack;
},
:stream<EVENTS>,
:consumer<replay-from-seq>,
:deliver-policy<by_start_sequence>,
:start-seq(1000);

# Replay from specific time
js-subscribe -> $msg {
    message.ack;
},
:stream<EVENTS>,
:consumer<replay-from-time>,
:deliver-policy<by_start_time>,
:start-time("2024-01-01T00:00:00Z">;
=end code

B<Options:>

=over 4

=item B<&block> - Code block to process messages (receives captured subject parts)

=item B<:stream> (required) - Stream name

=item B<:consumer> - Consumer name (auto-generated if not provided)

=item B<:filter> - Filter subject pattern (e.g., "orders.vip.*")

=item B<:batch> - Messages per fetch (default: 1)

=item B<:expires> - Fetch timeout in milliseconds

=item B<:deliver-policy> - Where to start consuming:
=item all - From the beginning
=item last - Last message only
=item new - Only new messages (default)
=item by_start_sequence - From :start-seq
=item by_start_time - From :start-time

=item B<:start-seq> - Start from this sequence number (with by_start_sequence)

=item B<:start-time> - Start from this time (ISO 8601 format)

=item B<:ack-policy> - none, explicit (default), or all

=item B<:max-deliver> - Max delivery attempts before giving up

=item B<:max-ack-pending> - Max unacknowledged messages allowed

=item B<:flow-control> - Enable flow control

=item B<:idle-heartbeat> - Idle heartbeat interval in milliseconds

=item B<:headers-only> - Only deliver headers, not payload

=back

=head2 subscribe

Defines a regular NATS core subscription (ephemeral, no persistence).

=begin code
# Basic subscription
subscribe -> "subject", "pattern" {
    say message.payload;
}

# With queue group (load balancing)
subscribe -> "tasks", :queue<workers> {
    say message.payload;
}

# With max messages limit
subscribe -> "temp", :max-messages(10) {
    say message.payload;
}
=end code

B<Route Pattern Syntax:>

=item B<Literal string>: C<"orders"> - matches exactly "orders"
=item B<Captured variable>: C<$id> - captures that position
=item B<Wildcard>: C<*> - matches any single token
=item B<Multi-token wildcard>: C<@tokens> - matches multiple tokens

B<Examples:>

=begin code
# Matches: "api.users.123.orders"
# Captures: $user-id = "123"
subscribe -> "api", "users", $user-id, "orders" {
    say "User: $user-id";
}

# Matches: "events.user.created", "events.order.deleted", etc.
subscribe -> "events", $entity, $action {
    say "$entity was $action";
}

# Matches: "logs.app.debug", "logs.app.error", etc.
subscribe -> "logs", "app", * {
    say "Log: ", message.payload;
}
=end code

=head2 message

Accesses the current L<Nats::Message> object inside a subscribe block.

=begin code
subscribe -> "orders", "created" {
    # Get payload
    say message.payload;
    
    # Get subject
    say message.subject;
    
    # Reply
    message.?reply: "Acknowledged";
    
    # Reply with JSON
    message.?reply-json: { :status<ok> };
}
=end code

=head1 COMBINING PATTERNS

When a parameter has multiple constraints, subscriptions will be created for
each combination:

=begin code
# Creates subscriptions for:
# - "orders.created"
# - "orders.updated"
subscribe -> "orders", "created" | "updated" {
    say "Order event: ", message.payload;
}
=end code

=head1 SEE ALSO

=item L<Nats::Client> - Client that uses these subscriptions
=item L<Nats> - Direct client for simple usage
=item L<Nats::Message> - Message object with reply methods

=head1 AUTHOR

Fernando Correa de Oliveira <fco@cpan.org>

=head1 LICENSE

Artistic-2.0

=end pod

use Nats;
unit class Nats::Subscriptions;

has @.subscriptions;

sub subscribe(&block, Str :$queue, UInt :$max-messages, Str :$subject) is export {
    my @subjects;
    
    if $subject {
        # Explicit subject provided
        @subjects = ($subject,);
    }
    else {
        # Derive subject from block signature
        my $sig    = &block.signature;
        my @params = $sig.params;

        @subjects = (
            [X] @params.map({
                .slurpy
                ?? (">",)
                !! .constraint_list || ("*",)
            })
        ).map: *.join: ".";
    }

    @*SUBSCRIPTIONS.append: do for @subjects -> $subj {
        -> Nats $nats {
            my $subscription = $nats.subscribe:
                      $subj,
                      |(:$queue with $queue),
                      |(:$max-messages with $max-messages),
            ;
            $subscription.supply.tap: -> $*MESSAGE {
                block |$*MESSAGE.subject.split(".")
            }
        }
    }
}

sub js-subscribe(&block, Str :$stream!, Str :$consumer, Str :$filter, 
                 Int :$batch = 1, Int :$expires, 
                 Str :$deliver-policy, Int :$start-seq, Str :$start-time,
                 Bool :$flow-control, Int :$idle-heartbeat,
                 Str :$ack-policy = "explicit", Int :$max-deliver,
                 Int :$max-ack-pending, Bool :$headers-only) is export {
    
    my $consumer-name = $consumer // $stream.lc ~ "-consumer-" ~ (@*SUBSCRIPTIONS.elems + 1);
    
    my %config = (
        type => 'jetstream',
        stream => $stream,
        consumer => $consumer-name,
        batch => $batch,
        block => &block,
    );
    
    # Optional JetStream consumer configuration
    %config<filter> = $filter if $filter;
    %config<expires> = $expires if $expires;
    %config<deliver-policy> = $deliver-policy if $deliver-policy;
    %config<start-seq> = $start-seq if $start-seq;
    %config<start-time> = $start-time if $start-time;
    %config<flow-control> = $flow-control if $flow-control.defined;
    %config<idle-heartbeat> = $idle-heartbeat if $idle-heartbeat;
    %config<ack-policy> = $ack-policy;
    %config<max-deliver> = $max-deliver if $max-deliver;
    %config<max-ack-pending> = $max-ack-pending if $max-ack-pending;
    %config<headers-only> = $headers-only if $headers-only.defined;
    
    @*SUBSCRIPTIONS.push: %config;
}

sub message is export {
    $*MESSAGE
}

sub subscriptions(&block) is export {
    my @*SUBSCRIPTIONS;
    block;
    Nats::Subscriptions.new: :subscriptions(@*SUBSCRIPTIONS)
}
