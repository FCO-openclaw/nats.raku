use v6;
use Nats;
use Nats::JetStream;

my $nats = Nats.new(servers => ["nats://nats_js:4222"]);

my $p = start {
    react whenever $nats.start {
        
        my $suffix = (^10000).pick;
        my $stream = "PSTREAM_$suffix";
        my $consumer = "PWORKER_$suffix";
        
        # Start a new thread for JetStream API calls to not block the NATS socket event loop!
        start {
            my $js = Nats::JetStream.new(:$nats);
            
            say "1. Configuring STREAM $stream...";
            $js.add-stream($stream, subjects => ["$stream.*"]);
            
            say "2. Adding Pull Consumer $consumer...";
            $js.add-consumer($stream, $consumer, filter-subject => "$stream.*");

            say $js.stream-info($stream);
            say $js.consumer-info($stream, $consumer);
            
            say "3. Publishing 3 messages to JetStream...";
            $nats.publish("$stream.ping", '{"id": 1}');
            $nats.publish("$stream.ping", '{"id": 2}');

            # Allow time for JS to process the messages
            sleep 1;
            
            say "4. Fetching batch of 2 messages...";
            my $count = 0;
            
            # This is the Pull Consumer part. It returns a Supply stream.
            my $supply = $js.fetch($stream, $consumer, batch => 2);
            
            $supply.tap(-> $msg {
                say "-> [Pull] Received message from JS: ", $msg.payload;
                if $msg.^can('ack') {
                    $msg.ack();
                    say "   [Pull] Message ACKed!";
                }
                $count++;
                if $count == 2 {
                    say "✅ Pull Consumer E2E Test: SUCCESS!";
                    exit 0; # Exits the docker script successfully
                }
            });
        }
        
        whenever Promise.in(8) {
            say "⏳Timeout waiting for pulled messages ❌";
            exit 1;
        }
    }
}

await Promise.anyof($p, Promise.in(15));
