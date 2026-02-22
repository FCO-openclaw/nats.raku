# NATS JetStream Architecture Proposal
**Status:** DRAFT (Discussion Phase)
**Date:** Feb 22, 2026

## 1. Architect's Proposal (`raku-architect`)
To support JetStream (JS) in `nats.raku` without bloating the Core NATS client, we should adopt a sub-namespace approach: `Nats::JetStream`. 
JetStream communication relies on standard publish/subscribe under the `$JS.API.>` subjects, with JSON payloads.
- **`Nats::JetStream::Client`**: Instantiated with an existing `Nats::Connection`. Provides helpers to create Streams and Consumers.
- **`Nats::JetStream::Stream`**: Represents a Stream.
- **`Nats::JetStream::Consumer`**: Represents a Consumer (Push or Pull).
- **JSON Marshalling**: Use `JSON::Fast` for payload conversions. We should add a generic helper in `Nats::JetStream::API` that wraps `request()` and automatically serializes to/from JSON, handling JS API errors (which return `+OK` or `-ERR` inside the JSON).
- **ACK logic**: JetStream messages need acknowledgment. Instead of changing `Nats::Message` heavily, we can add a `Role` or derive `Nats::JetStream::Message` that includes methods like `.ack()`, `.nak()`, `.term()`.

## 2. Backend Dev Feedback (`backend-dev-raku`)
I agree with the `Nats::JetStream::Message` class or Role. Using a Role `role JS-Ackable` that patches `Nats::Message` on the fly might be more idiomatic Raku and avoid code duplication.
- For JSON parsing, `JSON::Fast` is already the standard. We should ensure the async event loop (Supplier/Supply based in Raku) isn't blocked by large JSON decoding.
- Creating a Consumer should return a `Supply` that yields `JS-Ackable` messages.
- Let's keep the core `publish` method clean. If users want to use JS, they explicitly do: `$js.publish('my-subject', $data)`. This internal method will await an ACK from the JetStream server (a NATS publish returning an ACK in the payload).

## 3. QA Engineer Feedback (`qa-engineer`)
From a testing perspective:
- We must add a GitHub Action matrix testing against `nats-server -js`.
- The tests for push/pull consumers usually have race conditions in CI. We should implement a `Test::Mock` layer or use `await` with timeouts when expecting messages from JetStream.
- The `+ACK` response must be thoroughly tested. I propose adding a test suite `t/05-jetstream-basic.t` that just ensures the API `$JS.API.INFO` responds correctly before we dive into stream creation.

## Consensus & Next Steps
We have a unified agreement on:
1. Creating a `Nats::JetStream` namespace.
2. Using a `JS-Ackable` role for NATS messages.
3. Adding a test suite spinning up `nats-server -js`.

*Ready for Implementation Pair-Programming.*