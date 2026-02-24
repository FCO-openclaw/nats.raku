# use Grammar::Tracer;
unit grammar Nats::Grammar;

token subject {
    [<-[ . \s ]>+]+ %% '.'
}
token TOP {
    <msg-option>+ %% [\r? \n]
}
token sid { \d+ }
token size { \d+ }
token payload(UInt $size) {
    <(
        . ** { $size }
    )>
    <?before \n [\n | $]>
    \n
}
proto token msg-option           { * }
token msg-option:sym<OK>   { "+OK" \r? }
token msg-option:sym<ERR>  { "-ERR" \s+ $<err-msg>=[\N*] \r? }
token msg-option:sym<PING> { <.sym> \r? }
token msg-option:sym<PONG> { <.sym> \r? }
token msg-option:sym<INFO> { <.sym> \s+ $<info>=[\N*] \r? }
token msg-option:sym<MSG>  {
    <.sym>    \s+
    <subject> \s+
    <sid>     \s+
    [
        <reply-to=.subject> \s+
    ]??
    <size>    \r? \n
    {}
    <payload(+$<size>)>
}
