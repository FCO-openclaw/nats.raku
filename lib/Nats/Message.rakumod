use JSON::Fast;
use Nats::Replyable;
use Nats::JetStream::Ackable;

unit class Nats::Message;

has Str  $.subject;
has UInt $.sid;
has Str  $.payload;
has      $.nats where { .^can('publish') }

method TWEAK(Str :$reply-to) {
    if $reply-to {
        if $reply-to.starts-with('$JS.ACK.') {
            self does Nats::JetStream::Ackable if self !~~ Nats::JetStream::Ackable;
        } else {
            self does Nats::Replyable if self !~~ Nats::Replyable;
        }
    }
}

method json() {
    from-json($!payload);
}