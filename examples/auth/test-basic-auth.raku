use v6;
use Nats;

# This test connects to a NATS server using username/password authentication
# and publishes/receives a message to verify the connection works.

sub MAIN() {
    my $nats = Nats.new(
        username => "admin", 
        password => "password123",
        servers => ["nats://nats-basic:4222"]
    );
    
    my $test-complete = Promise.new;
    my $timeout = Promise.in(10);
    
    my $p = start {
        react whenever $nats.start {
            say "✅ Successfully connected to NATS server with basic auth!";
            
            # Create a subscription to receive the test message
            my $subject = "basic-auth-test";
            my $sub = $nats.subscribe($subject);
            
            # Listen for a message on our subscription
            $sub.tap(-> $msg {
                say "✅ Received message: ", $msg.payload;
                if $msg.payload eq "Basic auth test successful" {
                    $test-complete.keep(True);
                }
            });
            
            # Publish a message to our own subscription
            say "📤 Publishing test message...";
            $nats.publish($subject, "Basic auth test successful");
            
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
        say "✅ Basic authentication test completed successfully!";
        exit 0;
    } else {
        say "❌ Basic authentication test failed: ", $test-complete.cause;
        exit 1;
    }
}