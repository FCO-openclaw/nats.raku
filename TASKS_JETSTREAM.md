# Epic: NATS JetStream Support for nats.raku

## Context
The current `nats.raku` library supports basic NATS Core protocols (Publish, Subscribe, Request/Reply). We need to extend this to support the advanced features of JetStream, which provides persistent, at-least-once delivery, streams, and consumers.

## Requirements
- Support Stream Management (Create, Update, Delete, Info) via `$JS.API.STREAM.>` subjects.
- Support Consumer Management (Push, Pull, Info) via `$JS.API.CONSUMER.>` subjects.
- JSON structure serialization and parsing mapping to NATS JetStream REST-like API.
- Support message acknowledgments (`+ACK`, `-NAK`, `+WPI`, `+TERM`).

## Task List

### Task 1: Architectural Design (Discussion Required)
- **Assignees:** `raku-architect`, `backend-dev-raku`, `qa-engineer`
- **Objective:** Propose a scalable and idiomatic Raku architecture to support JS features without breaking core NATS performance. Should JS be a submodule (`Nats::JetStream`)? How should JSON unmarshaling impact performance?
- **Status:** In Progress.

### Task 2: Core JS Subject Wrapper & JSON Marshalling
- **Assignees:** `backend-dev-raku`
- **Objective:** Establish the foundation for sending requests to `$JS.API.>` subjects and parsing responses asynchronously. Include error handling for JS-level errors (not just core protocol errors).

### Task 3: Stream and Consumer Management APIs
- **Assignees:** `backend-dev-raku` // Pair programming with secondary dev
- **Objective:** Implement CRUD wrappers for Streams and Consumers.

### Task 4: Message Acknowledgment Subsystem
- **Assignees:** `qa-engineer` to define edge cases, `backend-dev-raku` to implement.
- **Objective:** Enhance the `Nats::Message` object structure to support Acking logic if the message originated from a JetStream subscription.

### Task 5: Integration Tests against NATS Server (JetStream enabled)
- **Assignees:** `qa-engineer`
- **Objective:** Write or adapt existing Integration Tests to fire up a `-js` NATS server and validate all endpoints.