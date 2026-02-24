use v6;
use Nats;
use Nats::JetStream;

my $nats = Nats.new(servers => ["nats://nats_js:4222"]);

my $p = start {
    react whenever $nats.start {
        
        my $suffix = (^10000).pick;
        my $stream = "PSTREAM_$suffix";
        my $consumer = "PWORKER_$suffix";
        
        start {
            my $js = Nats::JetStream.new(:$nats);
            
            say "1. Configuring STREAM $stream...";
            $js.add-stream($stream, subjects => ["$stream.*"]);
            
            say "2. Adding Pull Consumer $consumer...";
            $js.add-consumer($stream, $consumer, filter-subject => "$stream.*", ack-policy => "explicit");

            say "3. Publishing 100 messages to JetStream...";
            for 1..100 -> $id {
                $nats.publish("$stream.ping", '{"id": ' ~ $id ~ '}');
            }

            sleep 2;
            
            say "4. Fetching CONTINUOUS supply (NO batch limit provided)...";
            my $count = 0;

            # Providing NO batch parameter starts the infinite looper implementation
            my $supply = $js.fetch($stream, $consumer);
            
            $supply.tap(-> $msg {
                if $msg.^can('ack') {
                    $msg.ack();
                }
                $count++;
                if $count % 10 == 0 {
                    say "   [Pull] Consumed and ACKed $count/100... (Last Payload: {$msg.payload})";
                }
                if $count == 100 {
                    say "✅ Continuous Pull Consumer E2E Test: SUCCESS (100 messages)!";
                    exit 0;
                }
            });
        }
        
        whenever Promise.in(15) {
            say "⏳Timeout waiting for continuous messages ❌";
            exit 1;
        }
    }
}

await Promise.anyof($p, Promise.in(20));
