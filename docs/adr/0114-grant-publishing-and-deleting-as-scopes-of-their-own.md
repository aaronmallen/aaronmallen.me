---
id: "0114"
title: Grant publishing and deleting as scopes of their own
status: active
created: 2026-10-06
area: [lib, mcp]
issue: "#551"
amended: ["#941"]
tags: [mcp, oauth, scopes, tools, consent, publish, delete]
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

- **`publish`** guards the tools whose result nobody can call back: `publish_post` and `send_social_post`.
- **`delete`** guards every tool that removes a record for good: each `delete_*` tool and `remove_tag`.
- **`write`** keeps every other change, those a later call can undo among them: drop, archive, untag, unlink and
  cancel.

The consent page shows a line for each, and the warning that a post cannot be taken back sits on the `publish`
line, not on `write`. The server instructions in `MCP::Protocol::Handler` name the scope that grants publishing,
sending and deleting. ADR 0061's rule still applies: each scope has a name in `OAuthScope`, a consent line and
the tools that name it, and `MCP::Protocol::ScopedServer` withholds them from a token that lacks it.

## Alternatives

**One scope for both.** A client fit to clean up is not always fit to post in public, and the reverse holds too.
Two scopes cost one more consent line.

**Leave them on `write`** and trust the consent wording, as ADR 0061 did. Nothing checks wording.

**Put every tool that ends something under `delete`.** Dropping a sprint or archiving a project leaves the record
in place, and a later call brings it back, so those stay with the other edits on `write`.

## Consequences

A refresh never widens a grant (ADR 0061), so a client connected before this change keeps `read`, `suggest` and
`write`. It loses publishing, sending and deleting, and has to connect again, asking for `publish` and `delete`, to
get them back. The refusal it gets names the missing scope and says so.

A client that asks only for `write`, as every client did before, now connects without these tools and may not
learn why until it calls one.

A new tool that removes a record or publishes for good has to name the right scope. Nothing checks that it does
beyond `spec/slices/mcp/requests/scopes_spec.rb`, which lists each tool under the scope it expects.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
