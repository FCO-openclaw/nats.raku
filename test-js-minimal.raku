use v6;
use Nats;
use Nats::JetStream;

# Simplificado para uso sem Auth complicada
my $nats = Nats.new(servers => ["nats://nats_js:4222"]);

my $p = start {
    react whenever $nats.start {
        say "Connected to NATS server!";
        
        my $suffix = (^10000).pick;
        my $stream = "TEST_STREAM_$suffix";
        my $subject = "$stream.test";
        
        # Start a new thread for JetStream operations
        start {
            say "Creating JetStream client...";
            my $js = Nats::JetStream.new(:$nats);
            
            say "Adding stream $stream...";
            $js.add-stream($stream, subjects => [$subject]);
            
            say "Publishing message to $subject";
            $nats.publish($subject, '{"test": "data"}');
            
            # Give time for message to be stored
            sleep 1;
            
            say "Getting stream info...";
            my $info = $js.stream-info($stream);
            say "Stream info: $info";
            
            say "✅ JetStream basic test passed!";
            exit 0;
        }
        
        whenever Promise.in(10) {
            say "⏳ Timeout waiting for JetStream operations";
            exit 1;
        }
    }
}

await Promise.anyof($p, Promise.in(15));