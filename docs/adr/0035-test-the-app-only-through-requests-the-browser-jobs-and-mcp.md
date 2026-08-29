---
id: "0035"
title: Test the app only through requests, the browser, jobs and MCP
status: active
created: 2026-09-28
area: [app, lib, activity, admin, analytics, contact, mcp, posts, projects, public, record, social, suggestions, tags, tasks]
issue: AA-807
tags: [testing, rspec, coverage, capybara, sidekiq, mcp]
---

# ADR 0035: Test the app only through requests, the browser, jobs and MCP

![Active][status]

## Context

Most of the 442 spec files test one class at a time: 100 operation specs, 84 query specs, 38 component specs, and
more for repos, contracts, types, settings and providers. Some test gems rather than our code, such as
`spec/puma/configuration_spec.rb`. Some restate a value from config or the list of an enum. Eleven at the root of
`spec/` scan the source for broken rules.

These specs break whenever the code changes shape, even when its behavior holds. They also teach agents to write
more of the same, so the suite grows without catching more bugs. A spec that scans the source is a guardrail, and
guardrails belong in the context an agent reads, not in the suite.

## Decision

The suite drives the app only the ways a person or system reaches it:

- **HTTP requests**, through request specs.
- **The browser**, through browser specs in headless Chrome.
- **Sidekiq jobs**: enqueue or perform a job, then check what it changed.
- **MCP protocol requests** to `slices/mcp`.

We write no other kind of spec. That rules out:

- unit specs of an operation, query, repo, contract, type, component, provider or any other class;
- specs of how a gem behaves;
- specs that restate a config value or the values of an enum;
- specs that scan the source.

Where a unit spec guards real logic, a behavior spec replaces it before the unit spec goes, so no code sits
unguarded along the way. The move runs one slice at a time, and `lib/blog` counts as one. For each we record the
branch coverage the old suite gives it, then add behavior specs until they reach it.

Coverage may drop, but we keep it as high as we can. When a branch cannot be reached from outside, we check
whether it is dead code, and if it is, we delete it.

Browser specs run in the main suite. `mise run test` runs every spec in one process against one database and
reports branch coverage per file, browser specs included. Spec layout is free.

## Alternatives

**Delete every unit spec, then backfill.** It is the fastest way to a suite of one kind. It lost because it leaves
the code unguarded from the day the specs go until the backfill reaches it, and nothing would tell us which logic
lost its only spec.

**Freeze now and delete over time.** New code would get behavior specs only, and old unit specs would go as we
touched their code. It lost because the old specs keep breaking each time code changes shape, and while they stay
in the tree agents keep reading them and copying them.

## Consequences

The suite runs slower. Each example boots the full stack for a request, a job or a page, and browser specs drive
Chrome.

`mise run test` needs Chrome, on every machine and in CI.

Some coverage goes, where a branch only a unit spec reached turns out to be live. We live with that and name the
reason for each drop.

A failing spec names a page, a job or a tool call, not the class that broke, so finding the fault takes longer.

A class can change shape without touching a spec. Dead code shows up as branches no spec can reach.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
