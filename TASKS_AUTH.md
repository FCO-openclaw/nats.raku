# Epic: Authentication Support for nats.raku

## Context
The current `nats.raku` library assumes a locally running NATS server without any credential requirements (or uses the default connection mechanism). To support production environments, we need to implement authentication protocols during the initial `CONNECT` phase of the NATS protocol.

## Requirements
- Support Token-based authentication (passing standard string tokens).
- Support Username/Password authentication (Basic Auth).
- Support User Credentials (NKEY based authentications like `.creds` files or JWT seed pairs used extensively by NATS 2.0+ secure deployments).
- The authentication data should be safely encrypted/parsed and appended to the `CONNECT` JSON payload emitted when the Raku socket connects.

## Task List

### Task 1: Architectural Design (Discussion Required)
- **Assignees:** `raku-architect`, `backend-dev-raku`, `security-engineer`
- **Objective:** Propose an idiomatic way to pass these credentials via `URL` connections (e.g., `nats://user:pass@localhost:4222`), via constructor named arguments, or a dedicated `Nats::Auth` object. How will we parse and validate NKEYs using Raku?
- **Status:** Pending.

### Task 2: Core CONNECT Payload Updates
- **Assignees:** `backend-dev-raku`
- **Objective:** Update the `CONNECT` JSON emission in `lib/Nats.rakumod` (method `connect`) to conditionally inject `auth_token`, `user`, `pass`, `sig`, or `jwt` keys.

### Task 3: Token and Basic Auth Implementations
- **Assignees:** `backend-dev-raku` // Pair programming
- **Objective:** Wire up the simplest forms of auth (username, password, and bare tokens). Add unit tests for the JSON payload generation.

### Task 4: NKEY / JWT Signature Auth implementation (Challenge)
- **Assignees:** `backend-dev-raku`
- **Objective:** Implement ED25519 signing for the server challenge nonce returned during the `INFO` phase using Raku (might require binding to `libsodium` or pure Raku crypto if available).

### Task 5: Integration Tests against Secure NATS Server
- **Assignees:** `qa-engineer`
- **Objective:** Spin up a Docker `nats-server` configured with `--auth` and test all 3 modes of connections (Deny, Allow).