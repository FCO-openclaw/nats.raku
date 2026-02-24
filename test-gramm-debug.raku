use v6;
use Test;
use Test::Mock;
use lib 'lib';
use Nats;
use Nats::Subscription;
use Nats::Message;
my $supplier = Supplier.new;
my $conn = mocked IO::Socket::Async, returning => { Supply => $supplier.Supply };
my $socket-class = mocked IO::Socket::Async, returning => { connect => Promise.kept: $conn };
my $nats = Nats.new: socket-class => $socket-class;
$nats.start;
say "Emitting INFO";
try { $supplier.emit: 'INFO {}'; CATCH { default { say 'ERROR INFO: ', $_; .backtrace.print } } }
