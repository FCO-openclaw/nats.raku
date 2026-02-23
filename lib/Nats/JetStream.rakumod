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

#| Continuous polling mode wrapper. Yields a Nats::JetStream::Subscription built from batch sizes.
multi method fetch(Str $stream-name, Str $consumer-name, Int :$expires?, Bool :$no-wait?) {
    my $chunk-size = 100;
    
    my $supply = supply {
        loop {
            my $current-sub = self.fetch($stream-name, $consumer-name, batch => $chunk-size, :$expires, :$no-wait);
            whenever $current-sub.supply -> $msg {
                emit $msg;
            }
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
