use v6;
use Nats;

# This test connects to a NATS server using simple token auth via the JWT server configuration
# (full JWT with signature isn't implemented yet)

sub MAIN() {
    my $nats = Nats.new(
        token => "jwt_test_token",
        servers => ["nats://nats-jwt:4222"]
    );
    
    my $test-complete = Promise.new;
    my $timeout = Promise.in(10);
    
    my $p = start {
        react whenever $nats.start {
            say "✅ Successfully connected to JWT-configured NATS server with token auth!";
            
            # Create a subscription to receive the test message
            my $subject = "jwt-config-test";
            my $sub = $nats.subscribe($subject);
            
            # Listen for a message on our subscription
            $sub.tap(-> $msg {
                say "✅ Received message: ", $msg.payload;
                if $msg.payload eq "JWT config test successful" {
                    $test-complete.keep(True);
                }
            });
            
            # Publish a message to our own subscription
            say "📤 Publishing test message...";
            $nats.publish($subject, "JWT config test successful");
            
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
        say "✅ JWT config test completed successfully!";
        exit 0;
    } else {
        say "❌ JWT config test failed: ", $test-complete.cause;
        exit 1;
    }
}