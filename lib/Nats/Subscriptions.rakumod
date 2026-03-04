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
}

# Use with Nats::Client
my $client = Nats::Client.new: :$subscriptions;
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

sub subscribe(&block, Str :$queue, UInt :$max-messages) is export {
    my $sig    = &block.signature;
    my @params = $sig.params;

    my @subjects = (
        [X] &block.signature.params.map({
            .slurpy
            ?? (">",)
            !! .constraint_list || ("*",)
        })
    ).map: *.join: ".";

    @*SUBSCRIPTIONS.append: do for @subjects -> $subject {
        -> Nats $nats {
            my $sub = $nats.subscribe:
                      $subject,
                      |(:$queue with $queue),
                      |(:$max-messages with $max-messages),
            ;
            $sub.supply.tap: -> $*MESSAGE {
                block |$*MESSAGE.subject.split(".")
            }
        }
    }
}

sub message is export {
    $*MESSAGE
}

sub subscriptions(&block) is export {
    my @*SUBSCRIPTIONS;
    block;
    Nats::Subscriptions.new: :subscriptions(@*SUBSCRIPTIONS)
}
