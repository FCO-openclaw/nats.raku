use JSON::Fast;
use Nats::Replyable;
unit class Nats::Message;

has Str  $.subject;
has UInt $.sid;
has Str  $.payload;
has      %.headers;
has      $.nats where { .^can('publish') }

method TWEAK(:$reply-to) {
    self does Nats::Replyable($reply-to) if $reply-to && self !~~ Nats::Replyable;
    # Try to parse headers if payload includes NATS/1.0 header block
    if $!payload.starts-with('NATS/1.0') {
        my ($head, $body) = $!payload.split("\r\n\r\n", 2);
        my %h;
        for $head.lines.skip(1) -> $line {
            next unless $line.chars;
            my ($k, $v) = $line.split(':', 2);
            %h{$k.trim} //= [];
            %h{$k.trim}.push: $v.trim;
        }
        %.headers = %h;
        $!payload = $body // "";
    }
}

method json() {
    from-json($!payload);
}
