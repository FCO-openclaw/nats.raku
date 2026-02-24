use v6;
use Nats;
use Nats::JetStream;
use Nats::Message;

my $nats = Nats.new();

react whenever $nats.start {
    
    my $js = Nats::JetStream.new(:$nats);

    say "1. Testing STREAM creation...";
    # Create a stream
    my $info = $js.add-stream("EVENTS", subjects => ["EVENTS.*"]);
    say "Stream created: ", $info<config><name>;

    say "2. Testing CONSUMER creation...";
    my $consumer = $js.add-consumer("EVENTS", "WORKER_1", 
        filter-subject => "EVENTS.*", 
        deliver-subject => "MY.WORKER",
        ack-policy => "explicit"
    );
    say "Consumer created: ", $consumer<config><name>;
    
    my $messages-received = 0;

    say "3. Creating subscription to receive messages...";
    whenever $nats.subscribe("MY.WORKER").supply -> $msg {
        say "-> [Sub] Received JS Message: ", $msg.payload;
        if $msg.^can('ack') {
            say "   [Sub] Message CAN be acked! acking it now.";
            $msg.ack();
        } else {
            say "   [Sub] Oops, missing Ackable role on this msg? Subject: ", $msg.subject;
        }
        $messages-received++;
        
        if $messages-received == 2 {
            say "JetStream End-to-End Test: SUCCESS! 🎉";
            exit 0;
        }
    }

    say "Consumer info ready.";
    whenever Promise.in(1) {
        say "4. Publishing messages to the stream...";
        $nats.publish("EVENTS.login", '{"user":"fco"}');
        $nats.publish("EVENTS.logout", '{"user":"fco"}');
    }
    
    whenever Promise.in(3) {
        say "Total messages consumed via Push Consumer: ", $messages-received;
        say "JetStream End-to-End Test: FAILED 😢";
        exit 1;
    }
}