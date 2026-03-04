use JSON::Fast;
unit role Nats::Replyable;

# A classe principal ou a classe que aplica esse role deve ter esses atributos
has $.reply-to is required;

method reply(Str() $payload) {
    fail "No reply-to subject for reply" unless $!reply-to;
    self.nats.publish($!reply-to, $payload);
}

method reply-json(%payload) {
    self.reply: JSON::Fast::to-json(%payload);
}