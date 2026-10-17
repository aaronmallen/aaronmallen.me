---
id: "0140"
title: Word a field error by its key, and keep a table only for the exceptions
status: active
created: 2026-10-10
area: [lib, admin, api, public, mcp]
supersedes: ["0027"]
issue: "#1002"
amended: ["#1435", "#1559", "#1670"]
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

`Blog::UI::FieldError` words a code in five steps, in `lib/blog/ui/field_error.rb`:

1. The key `.<field>.<code>`, under the subclass's own scope in its slice's locale file.
2. The subclass's `OVERRIDES` table, for a code whose copy lives under another key.
3. The key `ui.field_error.<field>.<code>` in `config/i18n/shared/en.yml`, for a field every form words alike (#1670).
4. The key `ui.field_error.<code>` in `config/i18n/shared/en.yml`, for a code every form words alike (#1559).
5. `ui.field_error.invalid`, "Check this field.", in `config/i18n/shared/en.yml`.

Decisions word `option_id`'s `format` as `.option_id.missing`. Posts word a note's `long` with the edit note's copy.
A link field other than `url` points `format` at `ui.field_error.url.format` through `FieldError::URL`, the tag
form's `name` points at `ui.field_error.tags.format`, and mail words `cc` and `bcc` as `.to.format` (#1670).
Services needs none, since #1002 moved its keys under their fields.

`ui.field_error.control` reads "Take out the control characters." It replaced 29 copies of that line in the admin
locale file and the `.control` overrides calendar and decisions kept for it (#1559). A field that words `control` its
own way, such as the contact form's "hidden character" copy, keeps its own key, since step 1 comes first.

MCP tools and API endpoints still word codes through `API::Helpers::Wording`, and the MCP OAuth operations still
answer with the protocol's own codes, as ADR 0027 says.

## Alternatives

**Keep a row for every code (ADR 0027).** It lost because the rows repeated the locale file, and a missed row
failed quietly.

**Keep a copy of a shared code's copy under every field.** It lost because 29 fields held the same `control` line,
and each new field needed one more.

**Move every exception into the locale file.** Posts would write the edit note's copy twice, and decisions the
missing option's. A short table costs less than copy that drifts apart.

## Consequences

A new rule touches two places: the contract and the slice's locale file. Name the key after the field and the
code and the form finds it.

A key that matches by accident now shows. A stray `.<field>.<code>` left in a locale file is live copy, not dead
weight, so delete a key when its code goes.

A missing key still shows "Check this field." at run time, but `spec/lib/blog/ui/field_error_codes_spec.rb` fails
first (#1390). It reads the codes each contract can return, from its schema, `config/errors.yml` and the `failure`
calls in its rules and macros, and wants a key for each field the form shows, or a shared
`ui.field_error.<field>.<code>` or `ui.field_error.<code>` key. `mise run lint` fails on a locale key no code reads;
`.config/i18n/allowed.yml` lists the keys built at run time, field error keys among them.

`Public::UI::Components::ContactFieldError` words its codes the same way. It also hands the browser the copy for
`blank` and `format` before any code arrives, and finds those by the same `.<field>.<code>` key, so a field with no
such key hands the browser nothing for that code (#1435).

A field shows only its first code, as before.

`Admin::BulkAction` words a refused bulk action the same way: the page's own `<page>.toasts.bulk.invalid.<code>`
first, then `bulk_refusals.<code>` in the admin locale file (#1670).

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
