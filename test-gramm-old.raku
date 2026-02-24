grammar Test3 {
    token TOP { <msg-option>+ %% \r? \n }
    proto token msg-option { * }
    token msg-option:sym<PING> { <.sym> \r? }
}
say 'Test3 PING: ', Test3.parse("PING").gist;
