use JSON::Fast;
unit role Nats::Replyable;

has Str  $.reply-to;
has       $.nats is required;

method reply(Str() $payload = "") {
    $.nats.publish: $!reply-to, $payload
}

method reply-json(\json) {
    $.nats.publish: $!reply-to, to-json json
}
