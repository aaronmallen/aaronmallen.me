---
id: "0145"
title: Run specs in parallel with parallel_tests on a database per worker, and split CI into two spec jobs
status: superseded
created: 2026-10-10
area:
  - config
superseded-by: "0206"
issue: "#1082"
amended:
  - "#1393"
  - "#1960"
  - "#1973"
tags:
  - testing
  - rspec
  - parallel_tests
  - coverage
  - simplecov
  - ci
  - database
  - workspaces
---

# ADR 0145: Run specs in parallel with parallel_tests on a database per worker, and split CI into two spec jobs

![Superseded][status]

## Context

The suite runs in one process. Locally, the specs without the browser ones take 12 minutes for 9,524 examples at
63% CPU, about 75 ms an example, most of it waiting on Postgres. On CI the Test step took 12 to 14 minutes on
October 1 and 28 to 41 since October 7, in one job that runs lint, the schema check and every spec in turn on a four
core runner. No handful of slow specs explains it, so the fix is to use more cores.

Any split has to live with what the suite already does. `spec/support/db/cleaning.rb` empties only a database whose
name ends in `_test` or `_test_<id>`, and `spec/support/db/locks.rb` holds an advisory lock so two runs never share
one. [ADR 0125][0125] names the test database `<DATABASE_NAME or blog>_test_<id>` from `WORKSPACE_ID`, so agents
in different workspaces test side by side. SimpleCov writes one report to `coverage/` and has to keep doing so.

## Decision

`parallel_tests` runs spec files across processes, locally and on CI. Every way into the suite stays a mise task
under `scripts/test/`.

Each worker gets a test database of its own. The worker takes the name ADR 0125 gives, then adds `_w<n>` for
`TEST_ENV_NUMBER` when `parallel_tests` sets one: `blog_test_w2` in the root checkout, `blog_test_5_w2` in workspace
5. The first worker keeps the plain name, so a serial run and the first worker use the same database. The `w` keeps
a worker apart from a workspace: `blog_test_2` stays workspace 2's, never worker 2 of the root checkout. The guard in
`cleaning.rb` accepts the `_w<n>` ending, `scripts/test/prepare` prepares a database for every worker, and the
advisory lock stays.

Each process runs SimpleCov under a command name of its own, and the results merge into one report in `coverage/`.

On CI, `.github/workflows/ci.yml` runs four jobs: lint, Ruby specs, browser specs, and a last job that merges the
coverage from both spec jobs into one report and keeps it as a build artifact. Each spec job runs in parallel across
the runner's four cores. A failure in either spec job fails the workflow.

[ADR 0139][0139] still decides what we test. This record decides only how the suite runs.

Since #1960, [ADR 0206][0206] replaces RSpec with Gherkin features that run one server, Sidekiq, database and
Redis db per Playwright worker. The parallel RSpec setup here ends with the final delete in #1959.

## Alternatives

**An N-shard CI matrix split by recorded times.** Each shard repeats the setup the one job pays today: the gems,
the Postgres client and the database. The recorded times also go stale as specs change, and someone has to keep
them up to date.

**One CI job running in parallel.** Browser and Ruby specs would share the same four cores, and the job's time
stays the sum of both. Two jobs run side by side.

## Consequences

A run uses every core, so it finishes in a fraction of the time, and a push gets an answer sooner.

Each workspace now holds a test database per worker, not one. `dev:remove-workspace` has to drop all of them, and a
directory deleted by hand leaves more behind. `mise run dev:prune-workspaces` drops those, as [ADR 0125][0125] says.

A spec that leans on shared state outside its database now races its neighbours. Shared paths such as
`log/spec_examples.txt` need a name per worker, and the `:commits` specs that race threads under a timeout have to
stay stable under load.

Coverage is only whole once every process has written its results. A report read before the merge, or from one CI
job alone, shows less than the suite covers.

CI runs four jobs where it ran one, and each pays its own setup.

[0125]: 0125-make-agent-workspaces-with-mise-tasks-and-name-each-test-database-from-workspace-id.md
[0206]: 0206-replace-the-rspec-suite-with-black-box-gherkin-features-run-by-playwright-bdd.md
[0139]: 0139-test-through-behavior-first-and-unit-test-only-sql-parsers-and-logic-hard-to-reach-from-outside.md
[status]: https://img.shields.io/badge/0206-black?style=for-the-badge&label=Superseded&labelColor=orange
