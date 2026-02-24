use v6;
use Nats::Grammar;
my $p = "+OK\r\nMSG PSTREAM_8012.ping 4 \$JS.ACK.1.X 9\r\n\{\"id\": 1\}\r\n";
say Nats::Grammar.parse($p, :rule('TOP')).perl;