unit role Nats::JetStream::Ackable;

# A classe principal deve ter esses atributos
has $.reply-to;
has $.nats;

method ack() {
    fail "No reply-to subject for ACK" unless $!reply-to;
    self.nats.publish($!reply-to, "+ACK");
}

method nak() {
    fail "No reply-to subject for NAK" unless $!reply-to;
    self.nats.publish($!reply-to, "-NAK");
}

method term() {
    fail "No reply-to subject for TERM" unless $!reply-to;
    self.nats.publish($!reply-to, "+TERM");
}

method wpi() {
    fail "No reply-to subject for WPI" unless $!reply-to;
    self.nats.publish($!reply-to, "+WPI"); # Work and progress indicator
}
