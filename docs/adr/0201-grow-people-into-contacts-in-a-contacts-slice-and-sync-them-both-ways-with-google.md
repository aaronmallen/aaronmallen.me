---
id: "0201"
title: Grow People into contacts in a contacts slice and sync them both ways with Google
status: active
created: 2026-10-22
area:
  - admin
  - api
  - db
  - mail
  - mcp
  - services
  - social
issue: "#1936"
tags:
  - contacts
  - people
  - google
  - slices
  - sync
  - mentions
  - handles
---

# ADR 0201: Grow People into contacts in a contacts slice and sync them both ways with Google

![Active][status]

## Context

Spec #1933 brings my Google Contacts address book into the site. Today `people` holds a key, a name and a Mastodon or
Bluesky handle, and `people_handles_check` refuses a row with no handle. The `social` slice owns the table, since
mentions were its only reader ([ADR 0079][0079]). Mail already reads it to tell a known sender from a stranger, by
name.

Google connections live in the `services` slice ([ADR 0130][0130]), with one client at app level
([ADR 0159][0159]). The mail and calendar mirrors each own their sync in a slice of their own
([ADR 0150][0150], [ADR 0152][0152]).

A Google contact has no field for a Mastodon or Bluesky handle, only free text profile links. Mentions need the
handle exact, and the Bluesky DID resolved from it.

## Decision

**People grows into contacts, one record per person.** The `people` table keeps its name and gains every Google
Contacts field. A row needs a name or a company, not a handle, and needs a key only when it holds a handle. `@key`
mentions resolve as before.

**A new feature slice, `contacts`, owns the table** ([ADR 0001][0001]). Its relations, repos, contracts,
operations and the Google sync move there from `social`. `social` reads people for mentions, and `mail` for senders
and compose, through the read repos and operations `contacts` exports ([ADR 0123][0123]).

**The sync runs both ways.** A job pulls each Google connection that opts in every hour and on "Sync now", never
retries ([ADR 0012][0012]) and writes its outcome to `sync_states` ([ADR 0047][0047]). A contact deleted in Google
goes on the next pull. A create, edit or delete here calls Google on save, and a new contact goes to the account a
setting names. Each contact remembers its account.

**Google wins a conflict.** A save carries the version of the contact we last pulled. When Google holds a newer one,
the save fails, Google's version loads, and an error tells me to redo the edit.

**Handles stay local.** The Mastodon and Bluesky handles, the Bluesky DID and the key are ours. A push writes the
handles to Google as profile links, and a pull never reads those links back.

## Alternatives

**A contacts table beside People.** Each table keeps its own job, but someone I mention and mail is two records,
and mail, compose and mentions each have to match one to the other.

**Keep the table in `social`.** No code moves, but phones, addresses and a Google sync have nothing to do with
social posts, and `mail` would reach into `social` for its senders.

**The newest edit wins.** It keeps the later change, wherever it came from, but it has to trust two clocks and
drops the other edit without a word. A save here reaches Google at once, so a conflict needs an edit in Google since
the last pull, and Google winning loses only the edit I am still looking at.

**Read the handles back from Google.** An edit in Google would reach mentions, but a profile link is free text. A
typo there would break a mention, or point a stored DID at the wrong account.

## Consequences

Anyone I know can be a contact, mentionable or not. Mail matches senders by email, and compose and mentions draw
from one list.

The people code moves from `social` to `contacts`, and every import of it changes with it. The table keeps the name
`people`, so the search view reads it as before.

Google is the truth for every field but the handles and key. A change in Google shows here up to an hour late, and an
edit here can be lost to one made in Google first.

A handle changes only here. An edit to those links in Google lasts until I next save the contact here.

Each connection has to grant the contacts scope again, and the Google project needs the People API on, both outside
the code. Phones, addresses and notes land in the nightly backups ([ADR 0105][0105]).

[0001]: 0001-split-the-app-into-slices-by-feature.md
[0012]: 0012-never-retry-a-scheduled-job-and-make-its-next-run-catch-up.md
[0047]: 0047-keep-every-syncs-state-in-records-sync-states-table-keyed-by-kind-sync-and-repo.md
[0079]: 0079-store-a-mention-as-a-token-expanded-at-delivery.md
[0105]: 0105-dump-the-database-nightly-to-a-private-backups-bucket-and-keep-the-newest-7.md
[0123]: 0123-export-only-read-repos-and-operations-and-keep-write-repos-in-their-slice.md
[0130]: 0130-keep-service-credentials-encrypted-in-a-services-slice-and-define-each-service-in-code.md
[0150]: 0150-mirror-gmail-and-contact-messages-in-a-mail-slice.md
[0152]: 0152-mirror-google-events-in-a-calendar-slice-and-write-every-change-back-to-google.md
[0159]: 0159-group-shared-lib-code-by-service-and-register-service-clients-at-app-level.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
