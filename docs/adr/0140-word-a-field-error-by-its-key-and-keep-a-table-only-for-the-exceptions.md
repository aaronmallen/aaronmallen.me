---
id: "0140"
title: Word a field error by its key, and keep a table only for the exceptions
status: active
created: 2026-10-10
area: [lib, admin, api, public, mcp]
supersedes: ["0027"]
issue: "#1002"
tags: [contracts, validation, errors, i18n, dry-validation, forms]
---

# ADR 0140: Word a field error by its key, and keep a table only for the exceptions

![Active][status]

## Context

ADR 0027 has a contract fail with a short code and lets whatever draws the failure word it. Each form's
`Blog::UI::FieldError` subclass did that through a `MESSAGES` table that mapped field and code to an i18n key.
Thirteen sat under `slices/admin/ui/components` by #1002, and nearly every row read
`field: { "code" => ".field.code" }`: it said again what the locale file already said.

The cost showed. #960 gave tag names a `control` code and its copy, but no row in the tags table, so the form
said "Check this field." while every spec passed. `tasks.field_error.list.format` sat in the locale file with no
row and no code to reach it.

## Decision

A contract still fails with a short String code, never with copy. `config/errors.yml`, the rules and the
operations hand out codes as ADR 0027 lists them, and `Blog::Operation#validated` hands them up as
`Failure([:invalid, errors])`.

`Blog::UI::FieldError` words a code in three steps, in `lib/blog/ui/field_error.rb`:

1. The key `.<field>.<code>`, under the subclass's own scope in its slice's locale file.
2. The subclass's `OVERRIDES` table, for a code whose copy lives under another key.
3. `ui.field_error.invalid`, "Check this field.", in `config/i18n/shared/en.yml`.

Two admin subclasses keep overrides. Decisions word `control` on every text field with one shared `.control`, and
`option_id`'s `format` as `.option_id.missing`. Posts word a note's `control` and `long` with the edit note's copy.
Services needs none, since #1002 moved its keys under their fields.

MCP tools and API endpoints still word codes through `API::Helpers::Wording`, and the MCP OAuth operations still
answer with the protocol's own codes, as ADR 0027 says.

## Alternatives

**Keep a row for every code (ADR 0027).** It lost because the rows repeated the locale file, and a missed row
failed quietly.

**Move every exception into the locale file.** Decisions would write the `control` copy five times, and posts the
edit note's copy twice. A short table costs less than copy that drifts apart.

## Consequences

A new rule touches two places: the contract and the slice's locale file. Name the key after the field and the
code and the form finds it.

A key that matches by accident now shows. A stray `.<field>.<code>` left in a locale file is live copy, not dead
weight, so delete a key when its code goes.

A missing key still shows "Check this field." and no spec fails, as it did under ADR 0027. Nothing checks that a
code a contract can return has a key.

`Public::UI::Components::ContactFieldError` words its codes the same way, but keeps a `MESSAGES` table, since it
hands the browser the copy for `blank` and `format` before any code arrives.

A field shows only its first code, as before.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
