unit role Nats::JetStream::Ackable;

# Basic JetStream acknowledgement helpers.
# These publish control messages to the message reply subject.

method ack() {
    next unless $.^can('nats') && $.^can('reply-to');
    $.nats.publish: $.reply-to, "+ACK";
}

method nak() {
    next unless $.^can('nats') && $.^can('reply-to');
    $.nats.publish: $.reply-to, "-NAK";
}

method in-progress() {
    next unless $.^can('nats') && $.^can('reply-to');
    $.nats.publish: $.reply-to, "+WPI";
}

method term() {
    next unless $.^can('nats') && $.^can('reply-to');
    $.nats.publish: $.reply-to, "+TERM";
}
