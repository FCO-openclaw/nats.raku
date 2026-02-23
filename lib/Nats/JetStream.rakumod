use JSON::Fast;

unit class Nats::JetStream;

has $.nats where { .^can('publish') && .^can('request') };
has Str $.prefix = '$JS.API';

#| Wrapper to send JSON payloads to JetStream API endpoints and parse the response
method api-request(Str $subject, $payload = %()) {
    my $full-subject = "$!prefix.$subject";
    my $supply = $!nats.request($full-subject, to-json($payload));
    # The MOP handles Nats request correctly as returning a Seq of promises or direct objects
    my $resp-msg = do { my $val = $supply[0]; $val ~~ Promise ?? await $val !! $val };
    
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
#| Returns a Raku Supply that yields $batch Nats::Message items asynchronously.
method fetch(Str $stream-name, Str $consumer-name, Int :$batch = 1, Int :$expires?, Bool :$no-wait?) {
    my $full-subject = "$!prefix.CONSUMER.MSG.NEXT.$stream-name.$consumer-name";
    
    my %payload = (batch => $batch);
    %payload<expires> = $expires if $expires;
    %payload<no_wait> = True if $no-wait;

    # Fetch handles the inbox generator and returns the underlying message Supply
    my $inbox = $!nats.gen-inbox();
    my $sub = $!nats.subscribe($inbox, max-messages => $batch);
    $!nats.publish($full-subject, to-json(%payload), reply-to => $inbox);
    
    # Return the supply directly for continuous or discrete polling
    $sub.supply;
}
