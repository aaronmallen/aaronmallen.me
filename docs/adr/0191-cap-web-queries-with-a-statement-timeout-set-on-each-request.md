---
id: "0191"
title: Cap web queries with a statement timeout set on each request
status: active
created: 2026-10-18
area: [config, lib]
issue: "#1795"
tags: [postgres, statement-timeout, puma, sidekiq, migrations, backups, connections, request-connection]
---

# ADR 0191: Cap web queries with a statement timeout set on each request

![Active][status]

## Context

Production runs two Puma workers of five threads each ([ADR 0172][0172]). `RequestConnection` holds one Postgres
connection for each request until the app replies. Cloudflare gives up on a visitor at 100 seconds, but Postgres
keeps going, and the palette aborts its fetch on each key without the abort ever reaching Postgres. Five slow
admin searches can hold every thread in a worker while the public site waits.

Nothing set `statement_timeout`. The web process, Sidekiq and `hanami db migrate` share one `DBProvider`, and
migrations run through the same gateway connection the app uses. The nightly `pg_dump` and the restore check run as
their own processes from settings. A slow migration or a long dump must not get cut off.

## Decision

`RequestConnection` sets `statement_timeout` on the connection it holds, through `set_config`, before it hands the
request on. The `web_statement_timeout` setting holds the limit in seconds, 15 by default, and
`WEB_STATEMENT_TIMEOUT` overrides it. Postgres cancels a query that runs past it, the action raises
`Sequel::DatabaseError`, and the site answers its usual 500 page.

Only Rack requests pass through `RequestConnection`, so Sidekiq jobs, migrations, the console, `pg_dump` and
`pg_restore` keep running without a limit.

## Alternatives

**Set it on connect in `DBProvider`.** A libpq `options` value or an `after_connect` hook costs nothing per
request, but `DBProvider` cannot tell Puma from `hanami db migrate` or `hanami run`. It tells only Sidekiq apart, so
every process that is not the worker, migrations among them, would take the web limit.

**Set it on the database role on the NAS.** That reaches every process, migrations and backups included, and it
lives outside the repository.

**A Rack timeout gem.** Ruby gives up on the request, but Postgres keeps running the query and the connection stays
busy until it ends.

## Consequences

Each request makes one more round trip to Postgres before the app runs. The limit stays on the connection after the
request, which is harmless: in the web process only requests and their after-reply writes use the pool.

A query the request runs on another thread checks out its own connection and runs without the limit.

The share host answers from `config.ru` ahead of the app's middleware, so its queries run without the limit.

A report or export that grows past 15 seconds fails where it used to finish slowly. Raising the setting is the fix
until the query gets faster.

[0172]: 0172-run-puma-as-two-preloaded-workers-with-yjit-and-two-malloc-arenas.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
