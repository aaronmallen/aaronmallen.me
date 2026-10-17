---
id: "0162"
title: Keep request, job and page load timing in a performance slice
status: active
created: 2026-10-14
area: [app, config, db, assets, analytics, public, admin, mcp]
issue: "#1251"
amended: ["#1735"]
tags: [performance, timing, requests, jobs, sidekiq, puma, after-reply, beacon, lcp, retention, rollups, p95]
---

# ADR 0162: Keep request, job and page load timing in a performance slice

![Active][status]

## Context

Pages feel slow, and the site records no time for a request, a query or a job. Nobody can say whether the Pi, the
trips to Postgres on the NAS, the queries, the assets or the network costs the time. Cloudflare keeps anonymous pages
for five minutes ([ADR 0090][0090]), so most visits never reach the Pi, and timing taken on the server alone misses
what most visitors see.

Spec #1250 asks the site to time every request in every slice, every Sidekiq job and every page load, and to show the
numbers in the admin and over MCP. The site sends nothing about its visitors to a third party
([ADR 0045][0045], [ADR 0087][0087], [ADR 0102][0102]), and that holds for timing too.

## Decision

**A new `performance` slice owns timing.** It holds the tables, the jobs that prune and roll them up, the operations
behind the admin Performance screen and the MCP read tool. `analytics` keeps counting readers and does not grow to
cover timing.

**A request writes its row after Puma sends the reply.** Middleware in the app times each request, counts its queries
and adds up their time, then registers a `rack.after_reply` callback that inserts the row. No visitor waits on the
trip to the NAS, and a failed insert is logged and never fails the request. A Sidekiq job writes its row from server
middleware when the job finishes, in the same thread.

**Browser timing travels with the beacon and lands in the slice's own table.** `beacon.js` adds page load time and
Largest Contentful Paint to what it posts to `/pulse`. The public action hands those fields to `performance`, which
stores them in its own table, not on `analytics_events`.

**Raw rows stay 30 days, and daily p50 and p95 stay for good.** A scheduled job rolls each day into p50 and p95 per
route and per job, as `analytics_rollup_*` does for readers, then prunes raw rows older than 30 days. Since #1735 a
failed job's raw row also keeps its error class and message, which go when the row does ([ADR 0185][0185]).

## Alternatives

**Honeybadger Insights and OpenTelemetry.** Both send the numbers to a third party, which the site will not do.

**Logs only.** Logs feed neither an admin screen nor an MCP tool, and keep no daily figures for good.

**A buffer in memory.** Each Puma process would hold its own, and a restart or deploy would lose what it held.

**A Sidekiq job per row.** Every request would trade one insert for a trip to Redis and a job, and the site's other jobs
would wait behind the timing rows.

**An inline insert.** The visitor would wait on the trip to the NAS, which is the cost we set out to measure.

## Consequences

The site can name its slow routes and jobs, and cached pages show up through the browser figures.

Every request and job now writes a row, so the NAS takes one more insert per request. The after-reply insert holds a
Puma thread after the reply, so under load a thread frees later than it did.

A row lost to a failed insert is gone. The numbers are close, not exact.

`/pulse` now carries two kinds of data that live in two slices, so a change to the beacon touches both.

Only daily p50 and p95 outlive 30 days. A question that needs a single slow request, or a figure the rollup does not
keep, has 30 days to be asked.

[0045]: 0045-count-visitors-with-a-daily-hash-and-no-cookies.md
[0087]: 0087-widen-what-analytics-keeps-with-a-monthly-hash-and-roll-up-each-pages-breakdowns.md
[0090]: 0090-let-cloudflare-keep-anonymous-public-pages-for-five-minutes.md
[0102]: 0102-count-each-posts-unique-readers-with-an-undated-hash-kept-for-12-months.md
[0185]: 0185-keep-a-failed-jobs-error-on-its-performance-jobs-row.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
