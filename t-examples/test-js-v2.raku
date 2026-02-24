use v6;
use Nats;
use Nats::JetStream;

my $nats = Nats.new;

my $p = $nats.start;

# Give it a tiny bit to connect
sleep 0.5;

my $js = Nats::JetStream.new(:nats($nats));

# Randomize to avoid colliding with old streams in the docker instance
my $stream = "S" ~ (1000..9999).pick;
my $consumer = "C" ~ (1000..9999).pick;
my $delivery = "D" ~ (1000..9999).pick;
my $subj = "$stream.sub";

say "1. Testing STREAM creation... $stream";
$js.add-stream($stream, subjects => ["$stream.*"]);

say "2. Testing CONSUMER creation... $consumer ($delivery)";
$js.add-consumer($stream, $consumer, 
    filter-subject => "$stream.*", 
    deliver-subject => $delivery,
    ack-policy => "explicit"
);

my $messages-received = 0;

say "3. Creating subscription $delivery...";
my $sub = $nats.subscribe($delivery);

$sub.supply.tap(-> $msg {
    say "-> [Sub] JS Message: ", $msg.payload;
    if $msg.^can('ack') {
        say "   [Sub] ACKing message!";
        $msg.ack();
    }
    $messages-received++;
});

# Let NATS propagate the subscription
sleep 0.5;

say "4. Publishing to JS...";
$nats.publish($subj, "message 1");
$nats.publish($subj, "message 2");

sleep 1;

if $messages-received == 2 {
    say "JetStream End-to-End Test: SUCCESS! 🎉";
} else {
    say "JetStream End-to-End Test: FAILED 😢 (Got $messages-received)";
    exit 1;
}