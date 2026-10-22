---
id: "0114"
title: Grant publishing and deleting as scopes of their own
status: active
created: 2026-10-06
area:
  - lib
  - mcp
issue: "#551"
amended:
  - "#941"
  - "#1335"
  - "#1441"
  - "#1599"
  - "#1761"
  - "#1762"
  - "#1597"
tags:
  - mcp
  - oauth
  - scopes
  - tools
  - consent
  - publish
  - delete
---

# ADR 0114: Grant publishing and deleting as scopes of their own

![Active][status]

## Context

ADR 0061 gave every tool one scope out of `read`, `suggest` and `write`. `publish_post`, `send_social_post` and
every `delete_*` tool named `write`, the same as `update_post` and `save_task`. A client granted `write` to tidy
drafts could then put a post in front of readers or remove a record for good, and the only guard was the wording
on the consent page. The owner wants to grant edits without either power.

## Decision

`Blog::Types::OAuthScope` holds two more names, `publish` and `delete`. #941 corrected its name from
`MCP::OAuth::Scope::ALL`.

- **`publish`** guards every change that shows something in public. #1335 set this rule in place of "results nobody
  can call back", since an undo comes too late once a page has gone out and sits in the edge cache. It guards
  `publish_post` and `send_social_post`, and every call that uploads a share or a share group, adds a work entry,
  approves webmentions in bulk, changes the webmention settings or rewrites the edit note on a published post. It
  also guards each change whose target is public at the time: a project that is public after the change and its
  tags, a published or scheduled post and its tags and social card, a scheduled social post, an approved webmention,
  and a task on a published board ([ADR 0160][0160]), which takes in linking a task to such a project. #1441 added
  scheduled posts, since their text goes out with them, and an issue sync that can reach a published board: one a
  task rule files into, one that tracks a repo, or one that holds a synced task. #1597 added scheduled social posts
  for the same reason, and #1761 adding or editing a person whose key one of them mentions, since the post takes
  that person's handle or name, or the bare key when nobody holds it, when it sends ([ADR 0079][0079]).
- **`delete`** guards every tool that removes a record for good: each `delete_*` tool, `remove_tag` and
  `remove_trusted_author`. It also guards a spam verdict, one at a time or in bulk, when the author of any webmention
  it names sits on the trusted list, since the verdict takes them off it. #1599 added the trusted list, which #1441
  had left on `write`. A spam verdict on an author nobody trusts stays on `write`.
- **`write`** keeps every other change, those a later call can undo among them: drop, archive, untag, unlink and
  cancel. A change to a draft, a private project or a task on no published board stays here, as do task tags and
  time, which no public page shows. `drop_sprint` stays here too, though it deletes the sprint's row
  ([ADR 0050][0050]): only a sprint dated ahead can drop, its tasks go back to Next or External,
  `move_task` can already empty it and `plan_sprint` makes it again. #1762 corrected an earlier line that said
  dropping kept the row.

The consent page shows a line for each, and the warning that a post cannot be taken back sits on the `publish`
line, not on `write`. The server instructions in `MCP::Protocol::Handler` name the scope that grants publishing,
sending and deleting. ADR 0061's rule still applies: each scope has a name in `OAuthScope`, a consent line and
the tools that name it, and `MCP::Protocol::ScopedServer` withholds them from a token that lacks it.

A tool that needs `publish` or `delete` only for some targets keeps `write` as its scope. `API::Endpoint` refuses a
public target to a caller without `publish`, and the webmention endpoints refuse a spam verdict on a trusted author
to one without `delete`. Over the API that refusal is the same 403 `insufficient_scope` a missing scope gets, naming
the scope it lacks.

## Alternatives

**One scope for both.** A client fit to clean up is not always fit to post in public, and the reverse holds too.
Two scopes cost one more consent line.

**Leave them on `write`** and trust the consent wording, as ADR 0061 did. Nothing checks wording.

**Put every tool that ends something under `delete`.** Archiving a project leaves the record in place, and a later
call brings it back. Dropping a sprint deletes its row, but a `write` client could already empty it and plan it
again, as the `write` line says. Both stay with the other edits on `write`.

## Consequences

A refresh never widens a grant (ADR 0061), so a client connected before this change keeps `read`, `suggest` and
`write`. It loses publishing, sending and deleting, and has to connect again, asking for `publish` and `delete`, to
get them back. The refusal it gets names the missing scope and says so.

A client that asks only for `write`, as every client did before, now connects without these tools and may not
learn why until it calls one.

A client that holds `write` alone can no longer edit a public project, a published post or a task on a published
board, and has to connect again asking for `publish` to get that back. Nor can it approve a webmention, or sync
issues while a published board sits in the sync's reach.

A new tool that removes a record or shows something in public has to name the right scope, or check its target.
Nothing checks that it does beyond `spec/slices/mcp/requests/scopes_spec.rb`, which lists each tool under the scope it
expects, and `spec/slices/api/requests/publish_scope_spec.rb`, which tries each public target without `publish`.

[0050]: 0050-derive-today-from-sprint-membership.md
[0079]: 0079-store-a-mention-as-a-token-expanded-at-delivery.md
[0160]: 0160-open-a-public-page-for-each-task-on-a-published-board-without-its-tags-or-time.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
