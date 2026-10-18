---
id: "0193"
title: Hold the request's connection until Puma finishes the response
status: active
created: 2026-10-18
area: [config, lib]
issue: "#1787"
tags: [postgres, connections, connection-validator, puma, after-reply, response-finished, request-connection, timing]
---

# ADR 0193: Hold the request's connection until Puma finishes the response

![Active][status]

## Context

`RequestConnection` held one Postgres connection for each request, but only inside a `synchronize` block that ended
when the app returned. `RequestTimer` writes its row on `rack.after_reply` ([ADR 0162][0162]), which Puma runs after
the response goes out, so the row took a second checkout. The pool checks every checkout with `SELECT NULL` on
purpose (#234): a connection idle for a few seconds is as dead after a NAS restart as one idle for minutes. Every
request paid two round trips for that check.

The worker already shares one connection: `JobConnection` wraps `JobTimer`, so a job's row reuses the job's
connection. A Rack middleware cannot do the same with a block, because the reply goes out after every middleware
has returned.

## Decision

`RequestConnection` checks out its connection inside a `Fiber` that opens `synchronize` and yields. Sequel keys
connections by thread, so every query the request runs on that thread, after-reply callbacks included, reuses the
held connection without a second checkout. `RequestConnection` resumes the fiber, which gives the connection back,
from a `rack.response_finished` callback. Puma runs those after every `rack.after_reply` callback, in the same
thread, whether the app replied, raised or hijacked the socket: in Puma 8.0.2, `Puma::Response#handle_request`
returns `:async` for a hijack inside the method whose `ensure` runs both hooks. A server with no
`rack.response_finished` gets the connection back as soon as the app returns.

The pool still checks every checkout.

## Alternatives

**Check only connections idle past a few seconds.** It drops most `SELECT NULL`s, and undoes #234's reason.

**Put `RequestConnection` outside `RequestTimer`, as the worker does.** The block still ends before the reply goes
out, so the row still takes its own checkout.

## Consequences

A request and its timing row share one checkout and one check.

The timing row runs on the held connection, under the request's `statement_timeout` from [ADR 0191][0191]. The limit
applies to each statement, so the request's own queries do not use it up, and `RequestTimer` stops its clock before
the reply, so the insert never counts toward the row it writes.

The connection stays out of the pool while Puma writes the response and runs the after-reply hooks. A thread still
holds one connection at most, so a busy server needs no more of them: the pool holds Puma's threads plus one, and
no request waits on another thread's connection. When `DATABASE_MAX_CONNECTIONS` caps the pool below that, a thread
waits for a connection longer than it did, since each one now stays out for the whole response.

The admin event stream hands its socket to the live hub, which listens on a connection of its own outside the pool,
and returns. The request's connection goes back then, not when the stream closes, so an open admin tab holds none.

A server that skips `rack.response_finished` while offering the array would never give the connection back. Puma
calls it from an `ensure`, and a test that fakes Puma has to call it too: `Spec::AfterReply#reply` does.

[0162]: 0162-keep-request-job-and-page-load-timing-in-a-performance-slice.md
[0191]: 0191-cap-web-queries-with-a-statement-timeout-set-on-each-request.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
