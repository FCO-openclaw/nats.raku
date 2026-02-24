use v6;
use Nats;
use Nats::JetStream;

# This test verifies that the JetStream Pull Consumer works with authentication

sub MAIN() {
    my $nats = Nats.new(
        token => "test_token_123",
        servers => ["nats://nats-token:4222"]
    );
    
    my $test-complete = Promise.new;
    my $timeout = Promise.in(15);
    
    my $p = start {
        react whenever $nats.start {
            say "✅ Successfully connected to NATS server with token auth!";
            
            # Start a new thread for JetStream API calls to not block the NATS socket event loop
            start {
                my $suffix = (^10000).pick;
                my $stream = "AUTHSTREAM_$suffix";
                my $consumer = "AUTHWORKER_$suffix";
                
                my $js = Nats::JetStream.new(:$nats);
                
                say "1. Configuring STREAM $stream...";
                $js.add-stream($stream, subjects => ["$stream.*"]);
                
                say "2. Adding Pull Consumer $consumer...";
                $js.add-consumer($stream, $consumer, filter-subject => "$stream.*", ack-policy => "explicit");
    
                say "3. Publishing 5 messages to JetStream...";
                for 1..5 -> $id {
                    $nats.publish("$stream.msg", '{"id": ' ~ $id ~ '}');
                }
    
                say "4. Testing continuous fetch with authentication...";
                my $count = 0;
                my $supply = $js.fetch($stream, $consumer);
                
                $supply.tap(
                    -> $msg {
                        if $msg.^can('ack') {
                            $msg.ack();
                        }
                        $count++;
                        say "   [Pull] Received message #$count: {$msg.payload}";
                        
                        if $count == 5 {
                            say "✅ All 5 messages received successfully with authentication!";
                            $test-complete.keep(True);
                        }
                    },
                    quit => -> $ex {
                        say "❌ Error in supply: $ex";
                        $test-complete.break($ex.Str);
                    }
                );
            }
            
            # Set a timeout in case something goes wrong
            whenever $timeout {
                say "❌ Test timed out after 15 seconds";
                $test-complete.break("Timeout");
                exit 1;
            }
        }
    }
    
    # Wait for test to complete or fail
    await Promise.anyof($test-complete, $timeout);
    
    if $test-complete.status == Kept {
        say "✅ JetStream with authentication test completed successfully!";
        exit 0;
    } else {
        say "❌ JetStream with authentication test failed: ", $test-complete.cause;
        exit 1;
    }
}