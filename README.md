[![Actions Status](https://github.com/FCO-openclaw/nats.raku/actions/workflows/test.yml/badge.svg)](https://github.com/FCO-openclaw/nats.raku/actions)

📚 **[Full Documentation](https://fco-openclaw.github.io/nats.raku/)**

NAME
====

Nats - A Raku client for NATS.io messaging system

SYNOPSIS
========

    # Simple reactive style
    use Nats;

    given Nats.new {
        react whenever .start {
            whenever .subscribe("bla.ble.bli").supply {
                say "Received: { .payload }";
            }
        }
    }

    # Structured style with routing
    use Nats::Client;
    use Nats::Subscriptions;

    my $subscriptions = subscriptions {
        subscribe -> "bla", $ble, "bli" {
            say "ble: $ble";
            say "payload: ", message.payload;
            message.?reply-json: { :status<ok>, :$ble, :payload(message.payload) };
        }
    }

    my $server = Nats::Client.new: :$subscriptions;
    $server.start;
    react whenever signal(SIGINT) { $server.stop; exit }

    # Object-oriented style with JetStream
    use Nats;
    use Nats::JetStream;

    my $nats = Nats.new(servers => ["nats://localhost:4222"]);
    await $nats.start;

    # Subscribe to messages
    my $sub = $nats.subscribe("hello.>");
    $sub.supply.tap(-> $msg {
        say "Received: $msg.payload() on $msg.subject()";
    });

    # Publish messages
    $nats.publish("hello.world", "Hello from Raku!");

    # Request/Reply
    my $response = await $nats.request("service.status", "ping").head;

    # JetStream
    my $js = Nats::JetStream.new(nats => $nats);
    $js.add-stream("ORDERS", subjects => ["orders.>"]);

DESCRIPTION
===========

Nats is a Raku client for the NATS.io messaging system, a lightweight, high-performance cloud native messaging system. This module provides:

  * Core NATS protocol support (publish, subscribe, request/reply)

  * JetStream support for persistent messaging

  * Authentication (Token, Username/Password, JWT/NKeys)

  * Asynchronous messaging via Supplies

  * Two usage styles: simple reactive or structured with routing

USAGE STYLES
============

Simple Reactive Style
---------------------

Use the `Nats` class directly for a simple, reactive approach:

    use Nats;

    my $nats = Nats.new;
    react whenever $nats.start {
        whenever $nats.subscribe("orders.>").supply -> $msg {
            say "Received order: $msg.payload()";
        }
    }

Structured Style with Nats::Client
----------------------------------

Use `Nats::Client` and `Nats::Subscriptions` for a more structured, route-based approach similar to web frameworks:

    use Nats::Client;
    use Nats::Subscriptions;

    my $subscriptions = subscriptions {
        # Route: "users.<id>.orders"
        subscribe -> "users", $user-id, "orders" {
            say "User $user-id created an order";
            say "Payload: ", message.payload;

            # Reply with JSON
            message.?reply-json: {
                :status<created>,
                :user-id($user-id),
                :order-id(12345)
            };
        }

        # Route with wildcards
        subscribe -> "events", * {
            say "Event received: ", message.payload;
        }
    }

    my $server = Nats::Client.new: :$subscriptions;
    $server.start;

    # Graceful shutdown
    react whenever signal(SIGINT) {
        $server.stop;
        exit;
    }

**Route Patterns:**

  * Literal: `"users"` matches exactly "users"

  * Capture: `$user-id` captures that position

  * Wildcard: `*` captures any single token

ATTRIBUTES
==========

socket-class
------------

The socket class to use for connections. Defaults to `IO::Socket::Async`.

servers
-------

Array of NATS server URLs to connect to. Defaults to `nats://127.0.0.1:4222` or the `NATS_URL` environment variable.

supply
------

A Supply that emits [Nats::Message](Nats::Message) objects for incoming messages.

METHODS
=======

new
---

Creates a new NATS connection.

    # Basic
    my $nats = Nats.new;

    # With multiple servers
    my $nats = Nats.new(servers => ["nats://server1:4222", "nats://server2:4222"]);

    # With authentication
    my $nats = Nats.new(
        servers => ["nats://localhost:4222"],
        token => "my-secret-token"
    );

    # With JWT auth
    my $nats = Nats.new(
        jwt-path => "/path/to/jwt.creds",
        nkey-seed => "SU..."
    );

start
-----

Starts the connection to the NATS server.

    my $nats = Nats.new;
    await $nats.start;

stop
----

Closes the connection.

    $nats.stop;

subscribe
---------

Subscribes to a subject pattern.

    # Simple subscription
    my $sub = $nats.subscribe("foo.>");
    $sub.supply.tap(-> $msg { say $msg.payload() });

    # With queue group
    my $sub = $nats.subscribe("tasks", :queue("workers"));

    # With max messages
    my $sub = $nats.subscribe("notifications", :max-messages(10));

publish
-------

Publishes a message to a subject.

    $nats.publish("orders.created", "Order #12345");

    # With reply-to
    $nats.publish("service.request", "data", :reply-to("_INBOX.123"));

request
-------

Sends a request and returns a Supply with responses.

    my $response = await $nats.request("service.echo", "hello").head;
    say $response.payload();

    # Request with multiple responses
    $nats.request("service.status", "ping", :max-messages(5)).tap(-> $msg {
        say "Response from: $msg.subject()";
    });

ping
----

Sends a PING to the server.

    $nats.ping;

stream
------

Creates a [Nats::Stream](Nats::Stream) object.

    my $stream = $nats.stream("events", "events.created", "events.updated");

ENVIRONMENT
===========

  * NATS_URL - Default NATS server URL

  * NATS_DEBUG - Enable debug output

SEE ALSO
========

  * [Nats::JetStream](Nats::JetStream) - JetStream support

  * [Nats::Message](Nats::Message) - Message objects

  * [Nats::Subscription](Nats::Subscription) - Subscriptions

AUTHOR
======

Fernando Correa de Oliveira <fco@cpan.org>

LICENSE
=======

Artistic-2.0

