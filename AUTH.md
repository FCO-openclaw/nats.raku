# Authentication in nats.raku

This document provides details on the authentication mechanisms supported by the nats.raku library.

## Supported Authentication Methods

The library supports three authentication methods:

1. **Token-based authentication**: Simple token passed in CONNECT
2. **Basic authentication**: Username and password
3. **JWT/NKEY authentication**: JWT tokens with ED25519 signing (partial implementation)

## Usage

### Token Authentication

```raku
# Using a token for authentication
my $nats = Nats.new(token => "my_secret_token");
react whenever $nats.start { ... }
```

### Basic Authentication

```raku
# Using username and password authentication
my $nats = Nats.new(
    username => "admin", 
    password => "password"
);
react whenever $nats.start { ... }
```

### JWT/NKEY Authentication

```raku
# Using JWT and NKEY files
my $nats = Nats.new(
    jwt-path => "/path/to/user.jwt",
    nkey-path => "/path/to/user.nkey"
);
react whenever $nats.start { ... }

# Or with seed directly
my $nats = Nats.new(
    jwt-path => "/path/to/user.jwt",
    nkey-seed => "SUAIO..."  # Raw NKEY seed 
);
react whenever $nats.start { ... }
```

> **Note**: The JWT/NKEY authentication is not yet fully implemented as it requires ED25519 signing.

## URL-based Authentication

The library also supports parsing authentication credentials from the NATS URL:

```raku
# Token in URL
my $nats = Nats.new(servers => ["nats://token@localhost:4222"]);

# Username and password in URL
my $nats = Nats.new(servers => ["nats://username:password@localhost:4222"]);
```

## Implementation Details

### CONNECT Payload

When using authentication, the library modifies the CONNECT payload sent to the NATS server:

- For token authentication: `{"auth_token": "my_token", ...}`
- For basic authentication: `{"user": "username", "pass": "password", ...}`
- For JWT authentication: `{"jwt": "eyJhb...", "sig": "signed-nonce", ...}`

### JWT Authentication Flow

JWT authentication follows these steps:

1. Client connects to server
2. Server sends INFO with a `nonce` field
3. Client signs the nonce using its private NKEY
4. Client sends CONNECT with `jwt` and `sig` fields
5. Server verifies the signature against the public key in the JWT

## Security Considerations

- Passwords and tokens are sent in plain text in the CONNECT JSON
- TLS connections are recommended for production environments
- JWT authentication provides enhanced security with nonce signing

## Future Improvements

- Complete implementation of ED25519 signing for JWT authentication
- Support for NATS credentials file parsing (.creds)
- TLS certificate-based authentication