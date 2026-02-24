use v6;
use Nats::Grammar;
my $p = "MSG PSTREAM_8012.ping 4 \$JS.ACK.PSTREAM_8012.PWORKER_8012.1.1.1.X 9\r\n\{\"id\": 1\}\r\n";
say Nats::Grammar.parse($p, :rule('TOP')).perl;
