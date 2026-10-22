---
id: "0172"
title: Run Puma as two preloaded workers, with YJIT and two malloc arenas
status: active
created: 2026-10-14
area:
  - config
issue: "#1314"
amended:
  - "#1577"
  - "#1787"
tags:
  - puma
  - cluster
  - preload
  - fork
  - yjit
  - malloc
  - sidekiq
  - postgres
  - connections
  - raspberry-pi
  - systemd
---

# ADR 0172: Run Puma as two preloaded workers, with YJIT and two malloc arenas

![Active][status]

## Context

The web process was one Puma with 5 threads ([ADR 0006][0006], [ADR 0118][0118]). Markdown and Phlex rendering are
CPU bound, so under the GVL they take turns on one of the Pi's four cores. Ruby ran without YJIT, and glibc gave
each thread its own malloc arena, which grows the resident size of a threaded Ruby process.

`config/puma.rb` already forked when `HANAMI_WEB_CONCURRENCY` was above 1, and Puma 8 preloads the app by default
when it runs more than one worker. Its `before_fork` hook called `Hanami.shutdown`, which runs every provider's
`stop` in the master. Under preload that stops the live hub for good before any worker exists, so no worker could
start one.

Each process holds its own Postgres connections. `RequestConnection` holds one for each request and `RequestTimer`
writes its row on `rack.after_reply`, both through the pool `DBProvider` sizes at threads plus one. Since #1787 the
row reuses the request's connection ([ADR 0193][0193]).

## Decision

Production runs Puma as 2 workers with `preload_app!`. `HANAMI_WEB_CONCURRENCY` still sets the count, and it now
falls back to 2 in production and to 0 elsewhere.

Before each fork the master calls `Sequel::DATABASES.each(&:disconnect)` in place of `Hanami.shutdown`. The master
then holds no Postgres connection, each worker opens its own pool the first time it asks, and every provider stays
started, so each worker starts its own live hub on its first stream as [ADR 0118][0118] says.

`Hanami.shutdown` runs where each process ends instead. Puma calls it from `before_worker_shutdown` in each worker,
and Sidekiq from its `exit` event, so every provider's `stop` runs: the live hub joins its LISTEN thread and closes
its streams, and the MaxMind readers close. Sidekiq fires `shutdown` while its last jobs still run and `exit` once
they finish, so `exit` keeps the readers open for those jobs.

`config/puma.rb` and `config/sidekiq.rb` call `RubyVM::YJIT.enable` in production, when the Ruby was built with
YJIT.

The Puma and Sidekiq systemd units on the Pi set `MALLOC_ARENA_MAX=2`. glibc reads it when the process starts, so
the code cannot set it.

The Postgres budget at the defaults is:

| Process | Connections |
| --- | --- |
| Puma master | 0 |
| Each Puma worker | 6 in the pool (5 threads plus one) and 1 for the live hub, so 14 for both |
| Sidekiq | 11 in the pool (10 threads plus one) |
| Nightly `pg_dump` | 1 |
| `hanami db migrate` during a deploy | 1 |

That is 25 held and 27 at most, inside the 100 Postgres allows unless the NAS changed it.

## Alternatives

**jemalloc.** The issue offered it beside `MALLOC_ARENA_MAX`. It is a native library we would have to install on the
Pi by hand and load through `LD_PRELOAD`, where the arena cap is one variable in each unit.

**Keep `Hanami.shutdown` before the fork.** It disconnects the database too, but it also stops the live hub and
every other provider in the master, and nothing starts them again in the workers.

**Set YJIT through `RUBY_YJIT_ENABLE` in the units.** That keeps one more fact out of the repository, where the
next reader of `config/puma.rb` cannot see it.

## Consequences

Two requests can render at once, at the cost of a second copy of whatever each worker allocates after the fork.
YJIT adds code memory to each of the three processes. The Pi has 16GB, which leaves room.

Each worker added later costs 7 connections. Raising `HANAMI_WEB_CONCURRENCY` or `HANAMI_MAX_THREADS` means checking
the table above against the NAS `max_connections`.

A Ruby built without YJIT boots and runs without it, so nothing warns when it is off. `ruby --yjit -e 'p
RubyVM::YJIT.enabled?'` on the Pi says whether its Ruby has it.

`MALLOC_ARENA_MAX` lives in the units, outside the repository, and a rebuilt Pi needs it set again.

On macOS, a worker that opens its first Postgres connection after the fork crashes in libpq's GSS setup. Running
more than one worker in development there needs `PGGSSENCMODE=disable`. Linux does not have this problem.

[0006]: 0006-run-the-site-on-a-raspberry-pi-behind-a-cloudflare-tunnel-with-its-data-on-the-nas.md
[0118]: 0118-keep-admin-pages-live-through-postgres-notify-a-hijacked-event-stream-and-a-morph.md
[0193]: 0193-hold-the-request-connection-until-puma-finishes-the-response.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
