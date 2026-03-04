use v6;
use Nats;
use Nats::JetStream;

my $nats = Nats.new;

my $p = start {
    react whenever $nats.start {

        # In this react block, the Event Loop of NATS is active.
        my $js = Nats::JetStream.new(:$nats);
        
        # We need to dispatch JS actions inside standard promises 
        # so we don't block the supply processing thread
        start {
            say "1. Configuring JetStream (creating STREAM on server)...";
            $js.add-stream("EVENTS", subjects => ["EVENTS.*"]);
            say "Stream EVENTS created.";

            say "2. Adding Push Consumer...";
            $js.add-consumer("EVENTS", "WORKER_1", 
                filter-subject => "EVENTS.*", 
                deliver-subject => "MY.WORKER.INBOX",
                ack-policy => "explicit"
            );
            say "Consumer WORKER_1 created.";
        }

        # Handle messages arriving on the Consumer delivery subject
        whenever $nats.subscribe("MY.WORKER.INBOX").supply -> $msg {
            say "-> [PushConsumer] Received message: ", $msg.payload;
            if $msg.^can('ack') {
                say "   [PushConsumer] Message recognizes Ackable role. Sending ACK.";
                $msg.ack();
            }
        }
    }
}

# Wait connection
sleep 1;

# Out in the main thread space, simulate an external producer sending messages to JetStream
say "3. Simulating external Producer publishing JetStream entries...";
$nats.publish("EVENTS.login", '{"user": "fco", "action": "login"}');
$nats.publish("EVENTS.logout", '{"user": "fco", "action": "logout"}');

sleep 2;
say "JetStream execution completed successfully.";
