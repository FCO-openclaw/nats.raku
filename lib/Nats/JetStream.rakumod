=begin pod

=head1 NAME

Nats::JetStream - JetStream support for NATS.io in Raku

=head1 SYNOPSIS

=begin code
use Nats;
use Nats::JetStream;

my $nats = Nats.new(servers => ["nats://localhost:4222"]);
my $js = Nats::JetStream.new(nats => $nats);

# Stream Management
$js.add-stream("ORDERS", subjects => ["orders.>"]);
my $info = $js.stream-info("ORDERS");
my @streams = $js.stream-names();
$js.stream-delete("ORDERS");

# Consumer Management
$js.add-consumer("ORDERS", "processor", filter-subject => "orders.created");
my $consumer = $js.consumer-info("ORDERS", "processor");

# Pull Messages
my $sub = $js.fetch("ORDERS", "processor", batch => 10);
$sub.supply.tap(-> $msg {
    say "Received: $msg.payload()";
    $msg.ack();
});
=end code

=head1 DESCRIPTION

This module provides JetStream support for the NATS.io messaging system in Raku.
JetStream is a streaming platform built on top of NATS that enables:

=item At-least-once delivery
=item Stream persistence
=item Replay capabilities
=item Consumer groups
=item Exactly-once processing semantics

=head1 STREAM MANAGEMENT

=head2 method add-stream

Creates a new JetStream stream.

=begin code
method add-stream(Str $stream-name, :@subjects)
=end code

B<Parameters:>
=item $stream-name - Name of the stream
=item :@subjects - Array of subject patterns to capture

=head2 method stream-info

Get information about a specific stream.

=begin code
method stream-info(Str $stream-name)
=end code

=head2 method stream-list

List all streams.

=begin code
method stream-list()
=end code

=head2 method stream-names

Get an array of all stream names (convenience method).

=begin code
method stream-names()
=end code

=head2 method stream-delete

Delete a stream and all its data.

=begin code
method stream-delete(Str $stream-name)
=end code

=head2 method update-stream

Update an existing stream's configuration.

=begin code
method update-stream(Str $stream-name, :@subjects, :%config)
=end code

B<Parameters:>
=item $stream-name - Name of the stream to update
=item :@subjects - New subject patterns (optional)
=item :%config - Additional configuration options (optional)

B<Example:>
=begin code
$js.update-stream("ORDERS", subjects => ["orders.>", "returns.>"]);
=end code

=head1 CONSUMER MANAGEMENT

=head2 method add-consumer

Add a consumer to a stream.

=begin code
method add-consumer(Str $stream-name, Str $consumer-name, :$filter-subject, :$deliver-subject, :$ack-policy = "explicit")
=end code

B<Parameters:>
=item $stream-name - Name of the stream
=item $consumer-name - Name of the consumer
=item :$filter-subject - Only receive messages matching this subject (optional)
=item :$deliver-subject - Subject for push delivery (for push consumers)
=item :$ack-policy - Acknowledgment policy: "explicit", "none", or "all" (default: "explicit")

B<Examples:>
=begin code
# Pull consumer
$js.add-consumer("ORDERS", "processor", filter-subject => "orders.created");

# Push consumer
$js.add-consumer("ORDERS", "notifier", 
    filter-subject => "orders.urgent",
    deliver-subject => "notifications.urgent"
);
=end code

=head2 method consumer-info

Get information about a consumer.

=begin code
method consumer-info(Str $stream-name, Str $consumer-name)
=end code

=head2 method consumer-delete

Delete a consumer from a stream.

=begin code
method consumer-delete(Str $stream-name, Str $consumer-name)
=end code

=head2 method consumer-list

List all consumers for a stream.

=begin code
method consumer-list(Str $stream-name)
=end code

=head1 PULL CONSUMERS

=head2 method fetch

Fetch messages from a pull consumer.

=begin code
# Single batch
method fetch(Str $stream-name, Str $consumer-name, Int :$batch!, Int :$expires?, Bool :$no-wait?)

# Continuous polling
method fetch(Str $stream-name, Str $consumer-name, Int :$expires? = 100, Bool :$no-wait?)
=end code

=head1 AUTHOR

Fernando Correa de Oliveira <fco@cpan.org>

=head1 LICENSE

Artistic-2.0

=end pod

use JSON::Fast;
use Nats::JetStream::Subscription;

unit class Nats::JetStream;

has $.nats where { .^can('publish') && .^can('request') };
has Str $.prefix = '$JS.API';

#| Wrapper to send JSON payloads to JetStream API endpoints and parse the response
method api-request(Str $subject, $payload = %()) {
    my $full-subject = "$!prefix.$subject";
    
    my $prom = Promise.new;
    my $res = $!nats.request($full-subject, to-json($payload));
    if $res ~~ Supply {
        $res.head(1).tap(
            -> $msg { $prom.keep($msg) },
            done => { $prom.keep(Any) unless $prom.status }
        );
    } else {
        # Fallback if it returned a Seq directly
        $prom.keep($res[0]);
    }
    
    my $resp-msg = await $prom;
    $resp-msg = await $resp-msg if $resp-msg ~~ Promise;
    
    return do given $resp-msg {
        when .defined {
            my $data = from-json(.payload);
            # JS API returns errors in the JSON payload under 'error'
            fail "JetStream API Error: $data<error><description>" if $data<error>;
            $data;
        }
        default {
            fail "No response from JetStream API at $full-subject";
        }
    }
}

#| Info on a specific stream
method stream-info(Str $stream-name) {
    self.api-request("STREAM.INFO.$stream-name");
}

#| Add a new stream
method add-stream(Str $stream-name, :@subjects) {
    self.api-request("STREAM.CREATE.$stream-name", {
        name => $stream-name,
        subjects => @subjects
    });
}

#| List all streams
method stream-list() {
    self.api-request("STREAM.LIST");
}

#| Get array of stream names (convenience method)
method stream-names() {
    my $response = self.stream-list();
    my $streams = $response<streams>;
    # Ensure we return a proper Array
    return $streams.defined ?? ($streams ~~ Positional ?? $streams.list !! [$streams]) !! [];
}

#| Delete a stream
method stream-delete(Str $stream-name) {
    self.api-request("STREAM.DELETE.$stream-name");
}

#| Update an existing stream
method update-stream(Str $stream-name, :@subjects, :%config) {
    my %payload = name => $stream-name;
    %payload<subjects> = @subjects if @subjects;
    %payload{.key} = .value for %config;
    
    self.api-request("STREAM.UPDATE.$stream-name", %payload);
}

#| Info on a specific consumer
method consumer-info(Str $stream-name, Str $consumer-name) {
    self.api-request("CONSUMER.INFO.$stream-name.$consumer-name");
}

#| Add a new consumer to a stream (Push or Pull).
#| Provide :$deliver-subject for Push Consumer, pass none for Pull Consumer.
method add-consumer(Str $stream-name, Str $consumer-name, :$filter-subject, :$deliver-subject, :$ack-policy = "explicit") {
    my %config = name => $consumer-name, ack_policy => $ack-policy;
    %config<filter_subject> = $filter-subject if $filter-subject;
    %config<deliver_subject> = $deliver-subject if $deliver-subject;
    
    self.api-request("CONSUMER.CREATE.$stream-name.$consumer-name", {
        stream_name => $stream-name,
        config => %config
    });
}

#| Pull Consumer: fetch a given batch of messages actively. Single-shot query.
multi method fetch(Str $stream-name, Str $consumer-name, Int :$batch!, Int :$expires?, Bool :$no-wait?) {
    my $full-subject = "$!prefix.CONSUMER.MSG.NEXT.$stream-name.$consumer-name";
    my $inbox = $!nats.gen-inbox();
    
    my %payload = (:$batch);
    %payload<expires> = $expires if $expires;
    %payload<no_wait> = True if $no-wait;
    
    my $sub = $!nats.subscribe($inbox, max-messages => $batch);
    $!nats.publish($full-subject, to-json(%payload), reply-to => $inbox);
    
    Nats::JetStream::Subscription.new(
        sid => $sub.sid,
        subject => $sub.subject,
        supply => $sub.supply,
        nats => $!nats,
        batch => $batch,
        continuous => False
    );
}

#| Pull Consumer: fetch messages continuously via wildcard (*) batch
multi method fetch(Str $stream-name, Str $consumer-name, Whatever :$batch!, Int :$expires?, Bool :$no-wait?) {
    self.fetch($stream-name, $consumer-name, :$expires, :$no-wait);
}

#| Continuous polling mode wrapper using expiration only. Yields a Nats::JetStream::Subscription built from batch sizes.
# This version avoids busy looping by awaiting the completion of each batch and sleeping briefly if no messages are returned.
multi method fetch(Str $stream-name, Str $consumer-name, Int :$expires? = 100, Bool :$no-wait?) {
    my $chunk-size = 100;
    
    my $supply = supply {
        loop {
            my $current-sub = self.fetch($stream-name, $consumer-name, batch => $chunk-size, :$expires);
            whenever $current-sub.supply -> $msg {
                emit $msg;
            }
            # Await the completion of the current batch supply
            await $current-sub.supply.done;
            # Pause briefly to avoid a tight busy loop if no messages were received
            sleep 0.1;
        }
    };
    
    Nats::JetStream::Subscription.new(
        sid => 0, # Continuous stream masks multiple internal subscriptions
        subject => $stream-name, # For continuous polling, use stream as identification
        supply => $supply,
        nats => $!nats,
        batch => $chunk-size,
        continuous => True
    );
}
