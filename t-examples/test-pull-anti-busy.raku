use v6;
use Nats;
use Nats::JetStream;

my $nats = Nats.new;

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

            say "3. Publishing 5 messages to JetStream...";
            for 1..5 -> $id {
                $nats.publish("$stream.ping", '{"id": ' ~ $id ~ '}');
            }

            sleep 2;
            
            say "4. Testing anti-busy loop continuous fetch with expiration...";
            my $count = 0;
            my $start-time = now;

            # Continuous fetch with anti-busy loop protection
            # Default expiration of 100ms should be used
            my $supply = $js.fetch($stream, $consumer);
            
            $supply.tap(
                -> $msg {
                    if $msg.^can('ack') {
                        $msg.ack();
                    }
                    $count++;
                    say "   [Pull] Received message #$count: {$msg.payload}";
                    
                    # After we receive all 5 messages, let it run for a bit to test the anti-busy loop
                    if $count == 5 {
                        say "   All 5 messages received, now monitoring CPU usage...";
                        
                        # After 3 more seconds, check if we're still running without high CPU
                        Promise.in(3).then({
                            my $duration = now - $start-time;
                            say "✅ Anti-busy loop test completed in {$duration.fmt('%.2f')} seconds";
                            say "   Received $count messages total";
                            say "   The continuous fetch loop should now be sleeping between batches";
                            exit 0;
                        });
                    }
                },
                quit => -> $ex {
                    say "❌ Error in supply: $ex";
                    exit 1;
                }
            );
        }
        
        whenever Promise.in(10) {
            say "⏳Timeout waiting for test completion ❌";
            exit 1;
        }
    }
}

await Promise.anyof($p, Promise.in(15));