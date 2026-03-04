use JSON::Fast;
use Nats::Replyable;
use Nats::JetStream::Ackable;

unit class Nats::Message;

has Str  $.subject;
has UInt $.sid;
has Str  $.payload;
has $.nats is required where { .^can('publish') }
has Str $.reply-to is rw;  # Atributo explícito para reply-to

method TWEAK(Str :$reply-to) {
    if $reply-to {
        # Armazenamos o valor diretamente
        $!reply-to = $reply-to;
        
        if $reply-to.starts-with('$JS.ACK.') {
            if self !~~ Nats::JetStream::Ackable {
                # Aplicar role para mensagens JetStream
                self does Nats::JetStream::Ackable;
            }
        } else {
            if self !~~ Nats::Replyable {
                # Aplicar role para mensagens normais com reply-to
                self does Nats::Replyable;
            }
        }
    }
}

method json() {
    from-json($!payload);
}