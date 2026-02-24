use lib 'lib';
use Nats::Grammar;
use Nats::Actions;
use JSON::Fast;
my $ast = Nats::Grammar.parse('INFO {}', :actions(Nats::Actions.new)).ast;
