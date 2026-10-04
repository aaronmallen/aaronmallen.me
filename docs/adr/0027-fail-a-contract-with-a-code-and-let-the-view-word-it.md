---
id: "0027"
title: Fail a contract with a code and let the view word it
status: active
created: 2026-09-28
area: [lib, admin, public, mcp]
issue: AA-662
amended: ["#17", "#255"]
tags: [contracts, validation, errors, i18n, dry-validation, forms]
---

# ADR 0027: Fail a contract with a code and let the view word it

![Active][status]

## Context

A write runs a `Blog::Contract`, and a failure has to reach someone: the operator on an admin form, a stranger
on the contact form, or Claude through an MCP tool. dry-validation can hand back the words itself. Its message
backend looks a Symbol up in YAML or in I18n, and takes a String as the text.

Copy in this app lives in locale files, and Hanami gives each slice its own `i18n` component, loaded from
`config/i18n/shared` and then the slice's own `config/i18n` (`hanami-3.0.2/lib/hanami/providers/i18n.rb`).
dry-validation's `:i18n` backend reads the global `I18n`, which sees none of them. Its YAML backend reads the
files `Blog::Contract` names, which sit outside every slice.

## Decision

A contract fails with a short String code, never with copy. Whatever draws the failure turns the code into words.

Codes come from three places:

- `config/errors.yml`, which `lib/blog/contract.rb` loads, maps each predicate to a code: `filled?` to `blank`,
  `max_size?` to `long`, `excluded_from?` to `reserved`, too many `edits` to `many`, and `format?`, `int?`, `gt?`,
  `date?` and `included_in?` to `format`, except that a blank edit's `original` or `reason` fails `format?` as
  `blank` and an `other_id` past the id range fails `lt?` as `missing`.
- Rules pass a code to `key.failure`: `control`, `format` and `skipped` from `Blog::Contract`, and `future`,
  `blank`, `before_from`, `too_long`, `announcement_too_long`, `unavailable`, `missing` and `foreign` from slice
  contracts.
- An operation that hears of a clash from Postgres returns the same shape, `taken`, `locked`, `self` or
  `missing`: `slices/posts/operations/save_post.rb`, `slices/projects/operations/save_project.rb`,
  `slices/tags/operations/save_tag.rb` and `slices/tasks/operations/link_tasks.rb`.

`Blog::Operation#validated` hands the codes up as `Failure([:invalid, errors])`, and they become copy in three
places:

- Each form's `Blog::UI::FieldError` subclass, seven under `slices/admin/ui/components` and
  `Public::UI::Components::ContactFieldError`, maps field and code to a relative i18n key in its `MESSAGES`
  table. The key resolves under that component's scope in its slice's locale file. A code with no row falls back
  to `ui.field_error.invalid`, "Check this field.", in `config/i18n/shared/en.yml`.
- `MCP::Tools::SuggestEdits` and `MCP::Tools::WritePostSeo` word the codes for Claude in their `COMPLAINTS`
  tables.
- The MCP OAuth operations read which field failed and answer with the protocol's codes, such as
  `invalid_request` and `invalid_grant`, which no person reads.

## Alternatives

**dry-validation's `:i18n` backend.** The contract would fail with a Symbol and hand back finished copy. It lost
because it reads the global `I18n`, not the slice's `i18n`, so contract copy could not live in the slice's locale
files beside the rest of each form's copy.

**The YAML backend holding the copy.** `config/errors.yml` would say "Write something first." instead of `blank`.
It lost for the same reason: every slice's form copy would sit in one app-level file, apart from the form it
belongs to. The file stays, and holds codes.

**One `FieldError` for every form.** AA-411 turned this down. Each subclass resolves its keys through the scope
its class path gives it, so one component would mean one scope for every admin field and a `MESSAGES` table
handed in from outside. The eight share a base in `lib/blog/ui/field_error.rb` instead.

## Consequences

One contract serves a form and an MCP tool, and each words the same code for its own reader.

A new rule touches three places: the contract, the form's `MESSAGES` table and the slice's locale file. Miss the
row and the form shows "Check this field." while every spec passes. Miss the locale key and the page shows a
missing translation, which `spec/requests/translations_spec.rb` catches only on the paths it renders.

A field shows only its first code. A field failing two checks names one, and fixing it can bring up the next.

Codes are bare strings, written again in each `MESSAGES` table and `COMPLAINTS` table. Nothing checks that a code
a contract can return has a row anywhere.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
