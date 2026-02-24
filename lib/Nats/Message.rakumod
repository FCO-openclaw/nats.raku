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
            if self !~~ Nats::JetStream::Ackable {
                # Aplicar role e definir atributos necessários
                self does Nats::JetStream::Ackable;
                self.^attributes.grep({ .name eq '$!reply-to' })[0].set_value(self, $reply-to);
                # Não precisamos definir $!nats pois já existe na classe base
            }
        } else {
            self does Nats::Replyable if self !~~ Nats::Replyable;
        }
    }
}

method json() {
    from-json($!payload);
}