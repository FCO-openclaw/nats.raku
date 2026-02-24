use lib 'lib';
use Nats::Grammar;
say 'PING: ', Nats::Grammar.parse('PING').gist;
say 'PING\r\n: ', Nats::Grammar.parse("PING\r\n").gist;
