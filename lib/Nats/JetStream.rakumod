use JSON::Fast;

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

#| Pull Consumer: fetch a batch of messages actively
#| Returns a Raku Supply that yields Nats::Message items asynchronously.
#| If no :batch is supplied, it loops infinitely (continuous polling mode) using chunks of 100.
#| If :batch is supplied, it behaves in a single-shot query and closes the supply after N messages.
method fetch(Str $stream-name, Str $consumer-name, Int :$batch, Int :$expires?, Bool :$no-wait?) {
    my $full-subject = "$!prefix.CONSUMER.MSG.NEXT.$stream-name.$consumer-name";
    my $inbox = $!nats.gen-inbox();
    
    if $batch.defined {
        # Single-shot fetch
        my %payload = (batch => $batch);
        %payload<expires> = $expires if $expires;
        %payload<no_wait> = True if $no-wait;
        
        my $sub = $!nats.subscribe($inbox, max-messages => $batch);
        $!nats.publish($full-subject, to-json(%payload), reply-to => $inbox);
        return $sub.supply;
    } else {
        # Continuous streaming fetch over a unified Supply
        my $chunk-size = 100;
        my %payload = (batch => $chunk-size);
        %payload<expires> = $expires if $expires;
        %payload<no_wait> = True if $no-wait;

        # Keep subscription alive indefinitely (no max-messages)
        my $sub = $!nats.subscribe($inbox);
        
        my $supplier = Supplier.new;
        my $messages-in-chunk = 0;

        # Tap the underlying subscription to relay messages and trigger the next chunk request
        $sub.supply.tap(-> $msg {
            $supplier.emit($msg);
            $messages-in-chunk++;
            
            # Whenever we deplete the current requested chunk, we ask the server for more
            if $messages-in-chunk == $chunk-size {
                $messages-in-chunk = 0;
                $!nats.publish($full-subject, to-json(%payload), reply-to => $inbox);
            }
        }, done => {
            $supplier.done;
        }, quit => {
            $supplier.quit($_);
        });

        # Bootstrap the very first request
        $!nats.publish($full-subject, to-json(%payload), reply-to => $inbox);

        return $supplier.Supply;
    }
}
