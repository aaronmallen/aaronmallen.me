---
id: "0139"
title: Test through behavior first, and unit test only SQL, parsers and logic hard to reach from outside
status: active
created: 2026-10-10
area: [app, lib, activity, admin, analytics, api, backups, contact, decisions, links, mcp, media, posts, projects, public, record, saved_views, search, security, services, social, suggestions, tags, tasks]
supersedes: ["0035"]
issue: "#916"
tags: [testing, rspec, coverage, capybara, sidekiq, mcp, unit-specs]
---

# ADR 0139: Test through behavior first, and unit test only SQL, parsers and logic hard to reach from outside

![Active][status]

## Context

[ADR 0035][0035] let the suite drive the app only through requests, the browser, Sidekiq jobs and MCP, and ruled
out a unit spec of any class. The suite did not hold to it. About 32 specs under `spec/lib` and the `relations`,
`repos` and `operations` folders of `spec/slices` test one class, many of them added in October 2026, after the
record.

They guard code a request spec reaches only at a high cost: the checks and constraints a relation holds in
Postgres, the SQL behind a repo's rollups and searches, a parser such as `Posts::Markdown::Document` or the Linear
client, the sums and counts in `Analytics::Operations::RankRows` and `Social::Operations::MeasureParts`, two task
starts racing, and the settings and provider checks the app runs at boot. To reach each edge through a page would
take a page per edge.

The ban on specs that restate config or test a gem still holds. Those specs catch nothing and teach agents
to write more of them.

## Decision

Behavior specs come first. The suite drives the app the ways a person or system reaches it:

- **HTTP requests**, through request specs.
- **The browser**, through browser specs in headless Chrome.
- **Sidekiq jobs**: enqueue or perform a job, then check what it changed.
- **MCP protocol requests** to `slices/mcp`.

A unit spec is allowed only for code whose edges a behavior spec cannot reach at a fair cost:

- a relation's checks and constraints, and a repo's SQL;
- a parser of text or of a payload from another service;
- a calculation with many edges, such as a ranking or a count;
- a race between two writers, or a check the app runs at boot;
- a tool under `scripts/`, such as a RuboCop cop.

We still write none of these:

- specs of how a gem behaves;
- specs that restate a config value or the values of an enum;
- specs that scan the source;
- a unit spec of an operation, query, component or other class whose behavior a request, page, job or tool call
  already covers.

Browser specs run in the main suite, and `mise run test` reports branch coverage per file.

## Alternatives

**Hold to ADR 0035 and delete the unit specs.** The suite would match the record again. It lost because those specs
guard SQL and parsing that no behavior spec covers, so deleting them loses coverage, and reaching each edge from a
page costs far more.

## Consequences

The suite holds two kinds of spec, so a reviewer has to judge whether a new unit spec fits the list above. An agent
that sees one unit spec may copy it for a class that does not fit.

A relation, repo or parser that changes shape breaks its spec even when its behavior holds.

A failing unit spec names the class that broke, so finding the fault in SQL or a parser takes less time.

[0035]: 0035-test-the-app-only-through-requests-the-browser-jobs-and-mcp.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
