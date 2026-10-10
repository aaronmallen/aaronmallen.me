---
id: "0005"
title: Run every tool through a mise task and pin tool versions in mise.lock
status: active
created: 2026-09-28
area: [config]
issue: AA-654
amended: [AA-787, "#711", "#921", "#957"]
tags: [mise, tasks, lockfile, ruby, dotenv, pitchfork, ci, deploy]
---

# ADR 0005: Run every tool through a mise task and pin tool versions in mise.lock

![Active][status]

## Context

The project runs linters, formatters, a test suite, a server, a worker and asset watchers, on a laptop, in CI and
soon on the Pi. Each tool needs its flags and its config path, and some need Postgres running first. If each place
calls a tool its own way, the three drift apart, and a bare `rubocop` reads no config at all.

The tools need exact versions too. The Pi builds its own releases (ADR 0006), so it has to run the Ruby that the
laptop and CI test on.

## Decision

Every tool runs through a mise task, one entry point. Each task is a script under `scripts/`, which
`.config/mise.toml` pulls in through `[task_config] includes`. The script carries the flags, the config path and any
database check: `scripts/lint/ruby` runs `rubocop --config .config/rubocop.yml`, and `scripts/test/_default` runs
`rspec` through `scripts/util/ensure_postgres`, which starts Postgres when it is down. The script first asks
Postgres itself with `pg_isready` on `localhost` and `DATABASE_PORT`, and starts the compose service only when
nothing answers, so a Postgres that compose did not start still counts. Without the Postgres client, it asks
compose alone. AA-787 added the `pg_isready` check.

mise pins every tool and Ruby. `.config/mise.toml` asks for Ruby `"4"` and every other tool `"latest"`, with
`lockfile = true`, so the exact versions and checksums live in `.config/mise.lock`. The lock holds Ruby 4.0.7
(#957) with `compile = "true"`, built from source by ruby-build.

mise loads `.env` through `[env] _.file`. The Gemfile has no dotenv, so `Hanami::Env.load` returns at once.

Tool configs live under `.config/` to keep the repository root clean, and each task passes its file by flag.

`mise run dev` runs `pitchfork start --local` with `.config/pitchfork.toml`. Pitchfork starts the server only after
Postgres, Redis and the asset watchers, and the worker only after Postgres and Redis. It runs Postgres and Redis as
one-shot starts with nothing on exit, so `mise run dev:stop` leaves the shared containers up for any suite still
using them (AA-417). The script still ran `compose down`, so #711 made it stop only the pitchfork daemons and moved
the starts into `db:start` and `redis:start`, which pitchfork wraps ([ADR 0125][0125]).

CI installs the locked tools with `jdx/mise-action` and runs each step as a mise task. Postgres runs there as a
`postgres:18` service container, which GitHub starts and waits on before the first step, and `ensure_postgres` finds it
through `pg_isready`. AA-787 added the service container. #921 let runner setup with no laptop twin, such as installing
the Postgres client, run outside a task. It also moved the schema dump check into `mise run db:check`, which builds a
scratch database from the migrations, compares its dump to `config/db/structure.sql` and drops the database.

On the Pi, systemd starts Puma and Sidekiq through `mise exec`, which hands them the locked Ruby and `.env`. The tree
holds no units yet; AA-307 writes them.

So a laptop, CI and the Pi run the same tools, at the same versions, with the same flags.

## Alternatives

**`hanami dev` with a Procfile.** `hanami dev` runs `bin/dev`, which reads a Procfile. A Procfile gives its
processes no order, and it has no way to start Postgres and Redis and then leave them running, which AA-417 needs.

**dotenv.** Hanami loads `.env` itself once dotenv is in the bundle. mise already loads it for every task, so the gem
would do the same job twice.

**Configs at the root, where each tool looks.** No task would need a flag. It would put every file under
`.config/` back in the root, and since every tool runs through a task, the flag has one home anyway.

**A Gemfile `ruby` line with `.ruby-version`.** Bundler would refuse a Ruby that does not match. Every process gets
its Ruby from mise, the Pi's included, so the lock is the one pin. A second pin would have to move with it on each
upgrade.

## Consequences

No tool works run bare. `rubocop` from a plain shell reads no config, and a shell outside mise sees no `.env`, so
`bundle exec hanami console` there has no secrets (ADR 0007). With no `ruby` line in the Gemfile, a process started
outside mise runs on whatever Ruby it finds, and Bundler does not object.

A new tool needs a `lint:` and a `format:` script before `mise run lint` and `mise run format` reach it.

Every tool but Ruby asks for `"latest"`, so `mise upgrade` moves them all at once, and Ruby to the newest 4.x. Only
the lock says what ran.

`compile = "true"` means the Pi builds Ruby from source, which is slow and needs a compiler. `.config/mise.toml` does
not set it. The lock took it from the mise config of the machine that wrote it.

A task does not always suit the Pi. `mise run db:migrate` starts a local Postgres container first, so the deploy
calls `hanami db migrate` itself (ADR 0006).

[0125]: 0125-make-agent-workspaces-with-mise-tasks-and-name-each-test-database-from-workspace-id.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
