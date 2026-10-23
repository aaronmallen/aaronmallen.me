---
id: "0206"
title: Replace the RSpec suite with black-box Gherkin features run by playwright-bdd
status: active
created: 2026-10-23
area:
  - app
  - assets
  - config
  - db
  - lib
  - activity
  - admin
  - agents
  - analytics
  - api
  - backups
  - calendar
  - contacts
  - decisions
  - health
  - links
  - mail
  - mcp
  - media
  - notes
  - performance
  - posts
  - projects
  - public
  - record
  - saved_views
  - search
  - security
  - services
  - shares
  - social
  - suggestions
  - tags
  - tasks
supersedes:
  - "0139"
issue: "#1960"
tags:
  - testing
  - bdd
  - gherkin
  - playwright
  - playwright-bdd
  - typescript
  - rspec
  - fixtures
  - stub-server
  - sidekiq
---

# ADR 0206: Replace the RSpec suite with black-box Gherkin features run by playwright-bdd

![Active][status]

## Context

[ADR 0139][0139] tests through behavior first and keeps unit specs for SQL, parsers, calculations, races, boot checks
and `scripts/`. The RSpec suite runs inside Ruby to do it: rom-factory builds rows, specs forge the admin cookie,
stub `Time.now`, fake Sidekiq and stub outside services with WebMock. About 138 of its 546 files test one class.

Decision #9 weighs rewriting the server in Rust. A rewrite costs the proof that the new server behaves like the old
one, and a suite that loads Ruby cannot run against any server but this one. We also no longer want unit specs.
Spec #1959 settles what replaces them.

## Decision

Gherkin features, with steps in TypeScript and run by [playwright-bdd], replace every RSpec spec. They reach the app
only through HTTP, the browser, Postgres, Redis and child processes, and never load Ruby code, so the same features
can run against Hanami today and another server later. We write them against the Hanami app first.

- **Data.** TypeScript fixtures insert rows straight into Postgres, and the suite truncates it between tests.
- **Sign-in.** A TypeScript stub server plays GitHub OAuth, and settings point the OAuth URLs at it. Each Playwright
  worker signs in once through the real flow and reuses the saved state. API tokens come from SQL rows. MCP
  features connect through the real OAuth and PKCE flow.
- **Outside services.** The same stub server answers for every outside service: Google, mail, GitHub, Linear,
  LinkedIn, the social networks, webmentions and GeoLite. Settings point each client's base URL at it, and `Given`
  steps set its replies. No request leaves the machine.
- **Time.** Fixtures build data relative to the real clock. Playwright's `page.clock` drives browser timers. The
  server gets no time hooks.
- **Jobs.** A real Sidekiq runs per worker. Steps wait for a job's effect with `expect.poll`, and a step that runs a
  scheduled job pushes it onto the queue from TypeScript.
- **Scripts, schema and worker.** These become features too. Steps run scripts as child processes, issue SQL, and
  stop and start Redis, then check exit codes, output and rows.
- **Workers.** Each Playwright worker gets its own server, Sidekiq, database and Redis db.
- **Accessibility.** [`@axe-core/playwright`][axe] runs the [ADR 0036][0036] checks in light and dark, and the
  [ADR 0054][0054] phone checks move to the new suite. `page.route` takes the place of Capybara's request gate.

The suite lives in a `features/` package in an aube workspace, with its versions in the workspace catalog.
`mise run test:features` runs it until the delete, then `mise run test` does. CI gains a features job that caches
the Playwright browser.

We write every feature before we delete anything, so both suites run in CI until the end. A map lists each RSpec
example with the scenario that covers it, or the reason we drop it, such as "tests a gem" or "restates config". Once
the map has no gaps, one change deletes RSpec, Capybara, Cuprite, rom-factory, WebMock, parallel_tests, SimpleCov
and the coverage floor, with the tasks, CI jobs and records that name them.

## Alternatives

**Keep ADR 0139's unit specs beside the features.** They name the class that broke and guard SQL and parsers
cheaply. They lost because they load Ruby, so they cannot check another server, and we no longer want unit specs.

**Write the features in Capybara.** It keeps Ruby around only to run tests, where TypeScript stays in the repo
whatever server we run.

**Delete RSpec slice by slice as features land.** Each delete would lose coverage until its features cover every
example, with no single check that they do. Writing every feature first and gating the delete on the map keeps
both suites green until the last step.

## Consequences

The same features can gate a port of the server: a slice is done when its features pass against the new one.

Until the delete, CI runs both suites, and each change to behavior has to keep both green.

Fixtures write rows the app might never write, so a feature can pass on data the app could not make.

With no server time hooks, no feature can pin a midnight crossing or an exact timestamp.

A failing feature names the behavior that broke, not the class, so finding a fault in SQL or a parser takes
longer.

Each worker runs a server, Sidekiq, database and Redis db of its own, so a run needs more memory than RSpec did.

Every outside service needs a stub that answers like the real one, and a stub that drifts from its service passes
features the real service would fail.

[0036]: 0036-check-every-route-with-axe-core-in-the-browser-suite.md
[0054]: 0054-run-every-admin-screen-on-a-phone.md
[0139]: 0139-test-through-behavior-first-and-unit-test-only-sql-parsers-and-logic-hard-to-reach-from-outside.md
[axe]: https://github.com/dequelabs/axe-core-npm/tree/develop/packages/playwright
[playwright-bdd]: https://vitalets.github.io/playwright-bdd
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
