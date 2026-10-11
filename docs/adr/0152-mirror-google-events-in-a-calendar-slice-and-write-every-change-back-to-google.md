---
id: "0152"
title: Mirror Google events in a calendar slice and write every change back to Google
status: active
created: 2026-10-11
area: [admin, api, config, db, mcp, record, services]
issue: "#1124"
tags: [calendar, google, slices, sync, polling, recurring-events, work-calendars]
---

# ADR 0152: Mirror Google events in a calendar slice and write every change back to Google

![Active][status]

## Context

Spec #1119 puts my six Google calendars, across several accounts, on the admin calendar page beside posts, social
posts and sprints. Today that page reads only our own records, through `slices/api/repos/calendar_queries.rb`, and
`list_calendar` returns the same.

I want to plan from that page, not just read it: make an event, change it, delete it and drag it to another day.
Some calendars belong to my work account, and the site must not change them.

Google expands a recurring event into instances. A change to one instance can mean that day alone or the whole
series.

## Decision

A new feature slice, `calendar`, owns Google events ([ADR 0001][0001]). Its relations, repos, contracts and
operations live in `slices/calendar` ([ADR 0126][0126]). The calendar page and `CalendarQueries` read it through
its exported read repos and never write its tables ([ADR 0123][0123]).

**We mirror events into our own tables.** Each event keeps its title, calendar, start and end or all day, place,
Meet link, attendees and notes. Recurring events land as Google expands them, one row per instance. A scheduled job
polls every account that grants Google's full calendar scope every 15 minutes, never retries and catches up on its
next run ([ADR 0012][0012]), and writes its outcome to `sync_states` ([ADR 0047][0047]). It finds each account's
token through the `services` slice ([ADR 0130][0130]).

**Every write goes to Google.** Create, edit, delete and drag call the Calendar API, each from a plain form POST
([ADR 0055][0055]). The mirror copies Google, never the other way round.

**Work calendars refuse every write.** Each Google account records whether it is a work account, from a switch on
Connected services. The write operations refuse a calendar on a work account, or one Google lets me only read, so a
POST that skips the page fails too. The page offers no create, edit, delete or drag on them.

**A recurring instance asks.** Editing one asks "this event" or "all events" and changes what I pick. A drag moves
only that instance.

**Events sit under `read`.** `list_calendar` and the API return them to any token with `read`.

## Alternatives

**Read-only events, or drag only.** Each is less code, but I would still open Google to make or fix an event, and
the page exists so I don't have to.

## Consequences

The calendar page, the API and `list_calendar` read events from local rows, so the month draws without a call to
Google and a Google outage leaves the last mirror in place.

A change made in Google shows here up to 15 minutes late, and the site polls Google 96 times a day per account
whether or not anything changed.

A token with `read` sees my event titles, places, attendees and notes, work events among them.

A series that repeats daily takes a row a day, and "all events" has to reach the series
Google keeps, not the rows we hold.

Event details land in the nightly backups ([ADR 0105][0105]).

[0001]: 0001-split-the-app-into-slices-by-feature.md
[0012]: 0012-never-retry-a-scheduled-job-and-make-its-next-run-catch-up.md
[0047]: 0047-keep-every-syncs-state-in-records-sync-states-table-keyed-by-kind-sync-and-repo.md
[0055]: 0055-make-every-admin-write-a-plain-form-post-that-scripts-only-add-to.md
[0105]: 0105-dump-the-database-nightly-to-a-private-backups-bucket-and-keep-the-newest-7.md
[0123]: 0123-export-only-read-repos-and-operations-and-keep-write-repos-in-their-slice.md
[0126]: 0126-keep-only-base-classes-and-gem-wrappers-in-lib-and-give-the-rest-a-hanami-shape.md
[0130]: 0130-keep-service-credentials-encrypted-in-a-services-slice-and-define-each-service-in-code.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
