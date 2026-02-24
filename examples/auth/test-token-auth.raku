use v6;
use Nats;

# This test connects to a NATS server using token authentication
# and publishes/receives a message to verify the connection works.

sub MAIN() {
    my $nats = Nats.new(
        token => "test_token_123",
        servers => ["nats://nats-token:4222"]
    );
    
    my $test-complete = Promise.new;
    my $timeout = Promise.in(10);
    
    my $p = start {
        react whenever $nats.start {
            say "✅ Successfully connected to NATS server with token auth!";
            
            # Create a subscription to receive the test message
            my $subject = "token-auth-test";
            my $sub = $nats.subscribe($subject);
            
            # Listen for a message on our subscription
            $sub.tap(-> $msg {
                say "✅ Received message: ", $msg.payload;
                if $msg.payload eq "Token auth test successful" {
                    $test-complete.keep(True);
                }
            });
            
            # Publish a message to our own subscription
            say "📤 Publishing test message...";
            $nats.publish($subject, "Token auth test successful");
            
            # Set a timeout in case something goes wrong
            whenever $timeout {
                say "❌ Test timed out after 10 seconds";
                $test-complete.break("Timeout");
                exit 1;
            }
        }
    }
    
    # Wait for test to complete or fail
    await Promise.anyof($test-complete, $timeout);
    
    if $test-complete.status == Kept {
        say "✅ Token authentication test completed successfully!";
        exit 0;
    } else {
        say "❌ Token authentication test failed: ", $test-complete.cause;
        exit 1;
    }
}