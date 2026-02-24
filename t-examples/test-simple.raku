use v6;
use Nats;

# Simplified test without JetStream to verify basic connectivity
my $nats = Nats.new;

my $p = start {
    react whenever $nats.start {
        say "Connected to NATS server!";
        
        # Subscribe to a topic
        my $sub = $nats.subscribe("test.topic");
        
        # Publish a message
        $nats.publish("test.topic", "Hello from Raku!");
        
        # Handle incoming messages
        whenever $sub.supply {
            say "Received message: ", .payload;
            say "✅ Basic NATS test successful!";
            exit 0;
        }
        
        whenever Promise.in(5) {
            say "⏳ Timeout waiting for message";
            exit 1;
        }
    }
}

await Promise.anyof($p, Promise.in(10));