---
id: "0008"
title: Build the database URL from settings, in a db provider in every slice
status: active
created: 2026-09-28
area: [config, lib, activity, admin, analytics, contact, mcp, posts, projects, record, social, suggestions, tags, tasks]
issue: AA-594
amended: [AA-808, "#711", "#957"]
tags: [database, settings, providers, hanami, connection-pool, postgres]
---

# ADR 0008: Build the database URL from settings, in a db provider in every slice

![Active][status]

## Context

Hanami's database guide makes `DATABASE_URL` the main setting. Every slice inherits the app's gateway through
`config.db.configure_from_parent`, and the test database takes the same URL with `_test` on the name.

AA-353 put configuration in the settings files and left only secrets in the environment. `DATABASE_URL` carries the
password, so it has to live in the environment, and the host, port and name would go there with it. AA-405 made
every db task act on the one database its environment names, so `DATABASE_NAME` can point work at a second database
without touching the first.

Hanami's db provider finds a slice's URL only in the slice's own config or in `DATABASE_URL` and
`<SLICE>__DATABASE_URL`, and copies the parent's gateway config only when the two URLs already match
(`hanami/providers/db.rb`). A URL the app sets in code never reaches a slice.

AA-591 moved the app onto `DATABASE_URL` and dropped the slice providers. We canceled it on 2026-09-25 and kept
this shape.

## Decision

We build the connection from the `database` settings, never from `DATABASE_URL`.

- `Blog::Providers::DBProvider.configure` builds a `postgres://` URL from `settings.database`, escaping the user and
  password, and sets it on the default gateway.
- `config/providers/db.rb` and a three-line `config/providers/db.rb` in each slice with `relations/` call it. Twenty
  slices carry one today (#957).
- The pool holds a connection per thread plus one for the commit import lock, capped by `database.max_connections`
  (`DBProvider.max_connections`, AA-309). `DBProvider` reads Sidekiq's concurrency in the worker and the
  `web_threads` setting, which `HANAMI_MAX_THREADS` sets, in the web process (#957).
- `config/settings/test.yml` adds `_test` to `DATABASE_NAME` itself. #711 adds `_<id>` after it when
  `WORKSPACE_ID` is set, so each agent workspace tests against a database of its own ([ADR 0125][0125]).

## Alternatives

**`DATABASE_URL`, inherited by every slice.** One provider file instead of thirteen, and a new slice boots without
one. It lost because the whole address, host, port and name, would move out of the settings files into one secret,
against AA-353.

## Consequences

Every slice with relations needs its own provider file. A new slice without one fails boot with "A database_url for
gateway default is required to start :db."

Every slice builds the same URL and options, so Hanami's gateway cache hands them one gateway and one Sequel pool
per process. The pool size counts per process, not per slice: 6 in the web process and 11 in the worker at the
production defaults. A forked Puma worker opens a pool of its own.

A change to the gateway, such as an option or a Sequel extension, lands in `DBProvider` once and reaches every
slice.

Hanami's own test database step never runs, so we keep its `_test` rule in `test.yml`. The db tasks skip Hanami's
test rerun too: `scripts/util/db-command` passes `--skip-test-db`, so each task acts on the one database
`HANAMI_ENV` names (AA-405), and `scripts/setup/databases` prepares development and test in turn. A set `DATABASE_NAME`
names both: the name and the name with `_test`. A workspace sets `WORKSPACE_ID` instead, which moves only the test
database (#711).

[0125]: 0125-make-agent-workspaces-with-mise-tasks-and-name-each-test-database-from-workspace-id.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
