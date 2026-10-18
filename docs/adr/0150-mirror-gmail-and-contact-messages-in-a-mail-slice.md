---
id: "0150"
title: Mirror Gmail and contact messages in a mail slice
status: active
created: 2026-10-11
area: [db, admin, api, contact]
issue: "#1122"
amended: ["#1159", "#1381", "#1766", "#1779", "#1770"]
tags: [mail, gmail, google, contact, messages, slices, sync, polling, inbox, snooze]
---

# ADR 0150: Mirror Gmail and contact messages in a mail slice

![Active][status]

## Context

Spec #1119 brings my three Gmail accounts into the admin. I read contact form messages on one screen and Gmail in
another tab, so the inbox and Waiting tell half the story. The design puts both in one Mail screen, with the contact
form as a fourth account.

Contact form messages live in the `messages` table, which the `contact` slice owns. Its tags, its spam state and its
`snoozed_until` ([ADR 0121][0121]) all hang off that table, and `api` merges its waiting rows into the inbox
([ADR 0094][0094]).

Gmail has an API for threads, labels and a history of changes, and no API for snooze.

## Decision

**The `contact` slice grows into a `mail` slice.** It owns mail accounts, threads, messages and labels, and the public
contact form ([ADR 0001][0001]). Other slices read it through its exported read repos and operations
([ADR 0123][0123]).

**We mirror Gmail into our own tables.** Every page, count, search and Waiting rule reads local rows.

**Contact form messages move into the mail tables.** The contact form is one more account, with no Gmail behind it.
A migration moves every row of `messages` into a thread, with its tags, snooze and spam state, and `messages` goes.

**A job polls Gmail's history every few minutes**, the way [ADR 0146][0146] polls Google Health, so new mail lands
within five minutes. It never retries and catches up on its next run ([ADR 0012][0012]), and its outcome goes to
`sync_states` ([ADR 0047][0047]). A thread the database refuses would fail every later run too, so the sync skips
it, reports it to Honeybadger and goes on to the next thread and account. The thread comes back when Gmail next
changes it (#1766). The plain text body stops at 100,000
characters, well under the 1 MB Postgres allows its search vector. A thread whose history holds only label changes
costs a minimal fetch: the sync takes its read, starred, archived, spam, trash and label state from that, and fetches
the thread in full only when its messages differ from the ones stored (#1779). Each message keeps its own draft
flag, so a reply from the admin answers, and the list previews, the newest message that is not a draft (#1770).

**The backfill reaches back as far as the `mail.backfill_days` setting allows**, and skips trash. With no value set,
it takes every thread in each account but the trash. A lost history id starts the backfill over inside the same
window. Mail older than the window stays in Gmail and never reaches the site, unless a new message or a change lands
on its thread. Rows the site mirrored before the window was set stay until someone deletes them.

**Gmail holds a thread's state, and snooze and site tags stay here.**

| State | Lives in |
| --- | --- |
| Read, starred, labels, spam, trash, archive | Gmail. An action here writes to Gmail, then to the mirror. |
| Snooze | `snoozed_until` on the thread, as [ADR 0121][0121] keeps it on each record's table. |
| Site tags | `mail_thread_tags`. A new tag on a Gmail thread is a private site tag and never reaches Gmail. |
| Every state of a contact form thread | Our tables, since no Gmail stands behind it. |

## Alternatives

**Fetch Gmail live on each page.** No tables to keep in step. Every page waits on Google, and search, counts and
Waiting would need a Gmail call each.

**Keep the `messages` table and show it in Mail.** No migration. Every list, count and action would read two shapes
and merge them, in Mail and in every slice that reads messages.

**Gmail push through Pub/Sub.** Mail lands in seconds. It needs a Pub/Sub topic, a public endpoint and a watch to
renew, for mail a poll gets within minutes. It can come later.

## Consequences

Mail reads as fast as any other admin page, and works when Google is down.

The site polls Gmail around the clock whether or not mail came in. A change made in Gmail shows here only after the
next poll, so for a few minutes the two can disagree.

A snooze lives only here. Gmail and its apps show a snoozed thread in the inbox. A site tag on a Gmail thread lives
only here too, and Gmail never sees it.

The contact form keeps its guards ([ADR 0043][0043]) and its page ([ADR 0044][0044]), and now writes a thread.

Mail bodies sit in our database, so they land in the nightly backups ([ADR 0105][0105]). The backfill window bounds
how much of a mailbox they hold, and trash never lands from the backfill.

[0001]: 0001-split-the-app-into-slices-by-feature.md
[0012]: 0012-never-retry-a-scheduled-job-and-make-its-next-run-catch-up.md
[0043]: 0043-guard-the-contact-form-with-a-honeypot-and-a-daily-hash-not-a-cookie.md
[0044]: 0044-replace-the-contact-form-with-its-answer-on-a-page-load.md
[0047]: 0047-keep-every-syncs-state-in-records-sync-states-table-keyed-by-kind-sync-and-repo.md
[0094]: 0094-keep-a-seen-at-on-task-sources-and-merge-the-inbox-in-the-api-slice.md
[0105]: 0105-dump-the-database-nightly-to-a-private-backups-bucket-and-keep-the-newest-7.md
[0121]: 0121-keep-inbox-snoozes-in-a-snoozed-until-column-on-each-records-table.md
[0123]: 0123-export-only-read-repos-and-operations-and-keep-write-repos-in-their-slice.md
[0146]: 0146-keep-health-data-in-a-health-slice-as-daily-summaries-and-workouts-polled-from-google.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
