use lib 'lib';
use Nats::Grammar;
my $g = Nats::Grammar.parse('INFO {}');
say 'INFO {}: ', $g;
say 'info: ', $g<msg-option>[0]<info>;
