use v6;
use Nats::Grammar;
my $p = "MSG PSTREAM_9310.ping 4 \$JS.ACK.PSTREAM_9310.PWORKER_9310.1.1.1.177.1 9\r\n\{\"id\": 1\}\r\nMSG PSTREAM_9310.ping 4 \$JS.ACK.PSTREAM_9310.PWORKER_9310.1.2.2.177.0 9\r\n\{\"id\": 2\}\r\n";
say Nats::Grammar.parse($p, :rule('TOP')).perl;