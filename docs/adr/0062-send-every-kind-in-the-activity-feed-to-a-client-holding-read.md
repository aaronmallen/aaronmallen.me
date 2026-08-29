---
id: "0062"
title: Send every kind in the activity feed to a client holding read
status: active
created: 2026-09-28
area: [mcp, activity]
issue: AA-426
amended: [AA-434, AA-811, AA-824]
tags: [mcp, oauth, scopes, activity, journal, commits, privacy]
---

# ADR 0062: Send every kind in the activity feed to a client holding `read`

![Active][status]

## Context

The MCP server began as a proofreading door. A client read posts, drafts and all, and social posts not yet sent;
it sent suggested edits; it set a post's social card. All of that was text headed for the public site.

A review of the year needs the rest of the feed (AA-432). The `activities` view in `config/db/structure.sql`
unions every content kind, and most of them were never going public. A commit row carries the repository, the sha,
the whole message and the lines added and deleted, from private and employer repositories alike.

AA-348 settled four scopes in `lib/mcp/oauth/scope.rb`: `read`, `suggest`, `write` and `activity`, the last for
text not meant for the site. AA-824 then widened `read` to every record the backend keeps, the journal, commits,
contact messages and settings included. From then on `activity` guarded nothing `read` did not already hand over.

## Decision

The feed crosses to a client holding `read`. There is no `activity` scope: `Scope::ALL` holds `read`, `suggest`
and `write`, and the consent page spells out under `read` that it sends the journal and every commit whole
(`slices/mcp/config/i18n/en.yml`).

Two tools carry the feed, and `spec/slices/mcp/requests/scopes_spec.rb` pins the pair. `read_activity` sends rows.
`summarize_activity` (AA-434) sends counts by kind, by month and per repository, and no message, entry or title.
`MCP::Protocol::ScopedServer` leaves out of the list every tool a token's scopes do not cover and refuses a call
to one.

Every kind in the view crosses, and neither tool cuts one out: commits, posts, journal entries, social posts,
webmentions, tasks, projects, sprints and suggestions. A report on a date range reads one feed.

A commit crosses whole: repository, sha, full message, additions and deletions, private and employer
repositories included. A subject line is not what a review reads.

`read_activity` answers one window at a time: about 200 rows, rounded out to the end of a day, with `partial`
set and a `continue_to` day to send as `to` for the next window. The client may pass `kinds`, `repos`, `tags` and
`text`. These narrow a read, but the client picks them, so they control nothing.

`mcp` reads the feed through the queries the `activity` slice exports, never through a repo.

## Alternatives

**Keep the feed behind an `activity` scope**, as the first version of this record did, with three kinds crossing:
commit, journal and task. The everyday proofreading connector asked for `read suggest` and never saw the journal,
and a review took a second connector asking for `read activity`. A webmention stayed out, since its author name
and excerpt come off a stranger's page. It lost once AA-824 widened `read` to the journal, commits and messages
through their own tools: the scope then kept nothing from a `read` client, and it cost a second connector and a
consent line.

**Strip the repository name.** The label saying "employer" would stay behind. The message would still cross, and a
commit body usually says more about a project than its name does, so this hides the evidence rather than the
material.

**An allowlist of repositories.** A real control, and the only one here that can hold back one repository while
letting the rest through. Nobody has asked for it, and the list would have to keep step with every repository the
operator makes after it. The `repos` filter on `read_activity` is not this list, since the client sets it.

## Consequences

**This is where material from an employer repository leaves the machine.** A commit message naming an internal
system reaches whoever holds the token, which for claude.ai is not this machine. No tool can tell a commit worth
reviewing from one that should have stayed in, so the grant is the whole control.

**`read` alone reads the journal.** A client that names no scope gets `read` alone (`MCP::OAuth::Scope::DEFAULT`),
and both `scopes` columns in `config/db/structure.sql` default to `{read}`, so a proofreading connector now reads
private entries, private commits and text strangers wrote. One connector does both jobs, and there is one to revoke.

**A leaked token reads the journal for any range it asks for.** An access token lasts an hour and a refresh token
30 days (`slices/mcp/operations/issue_tokens.rb`), and the revoke button on the admin's clients page is the rest of
the limit.

**A year takes many calls.** One answer stops near 200 rows, and a feed of nine kinds fills a window sooner, so a
client counts first with `summarize_activity` and walks the months with `read_activity`, following `continue_to`.
A client that ignores `partial` sees only the newest rows of its window.

**Nothing here makes the feed public.** The view stays in the `activity` slice, and a token is not the public site.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
