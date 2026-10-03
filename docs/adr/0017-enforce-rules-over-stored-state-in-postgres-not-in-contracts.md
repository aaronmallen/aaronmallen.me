---
id: "0017"
title: Enforce rules over stored state in Postgres, not in contracts
status: active
created: 2026-09-28
area: [db, lib, admin, decisions, links, posts, projects, record, social, tags, tasks]
issue: AA-653
amended: [AA-816, "#17", "#77", "#143", "#274", "#319"]
tags: [postgres, constraints, triggers, contracts, validation, operations]
---

# ADR 0017: Enforce rules over stored state in Postgres, not in contracts

![Active][status]

## Context

A `Blog::Contract` sees only what arrived, plus any context the operation hands it. Some rules need more than
that. A slug must not match another post's. A published post's slug must not change. A project must not start after
the day it was archived, which the form does not send. Each of these reads a row other than the one in the form, or
the row as it stood before the edit.

An operation validates before it opens its transaction, so a check in Ruby reads rows that another writer can change
before the write lands. The scheduled posts job can publish a post while its editor is open.

The posts table set the pattern when it landed: the database enforces the rules, so no caller can skip them. A
unique index keeps slugs apart, and a trigger refuses a new slug on a post already published. AA-317 later swapped
the per-column checks for Postgres types and left every rule that spans columns or rows where it was.

## Decision

A rule over what arrived lives in the contract: presence, format, length, stray control characters, a reserved
slug, and a rule against the clock, which the operation passes as context, the way `ProjectContract` refuses a
start month in the future. A Postgres domain may hold the same rule as a floor under every write, the way
`non_blank_text` sits under a journal body, but the contract refuses first.

A rule over what is stored lives in Postgres, as a unique index, a `CHECK`, a trigger, a foreign key or a
singleton row. Nothing in Ruby checks it first.

One rule breaks this, as [ADR 0084][0084] records and #143 built. `Posts::Operations::SavePost` asks for an edit
note when the body of a published post changes. It checks in Ruby, after it locks the post's row, so the race above
cannot reach it, but the rule binds only callers that go through `SavePost`. Decisions follow it, as
[ADR 0099][0099] records and #274 built: `EditDecision` and `EditDecisionOption` ask for a note on a closed
decision under the decision's lock.

When a user can break such a rule from a form, the operation turns the refusal into a field error. It rescues
`ROM::SQL::UniqueConstraintError`, `CheckConstraintError` or `ForeignKeyConstraintError`, asks
`Blog::DB::Repo#violated_constraint` for the name, and looks the name up in a constant. A name it does not know
raises again.

| Constraint | Kind | Operation | Field error |
| --- | --- | --- | --- |
| `decisions_resolved_option_fkey` | foreign key | `Decisions::Operations::DeleteDecisionOption` | `id: chosen` |
| `decisions_resolved_option_fkey` | foreign key | `Decisions::Operations::ResolveDecision` | `option_id: missing` |
| `posts_slug_key` | unique | `Posts::Operations::SavePost` | `slug: taken` |
| `posts_published_slug_locked` | trigger | `Posts::Operations::SavePost` | `slug: locked` |
| `projects_repo_index` | unique index | `Projects::Operations::SaveProject` | `repo: taken` |
| `projects_archived_order_check` | `CHECK` | `Projects::Operations::SaveProject` | `started_on: after_archived` |
| `record_links_order_check` | `CHECK` | `Links::Operations::LinkRecords` | `other_id: self` |
| `record_links_pair_key` | unique index | `Links::Operations::LinkRecords` | `other_id: taken` |
| `record_links_record_missing` | trigger | `Links::Operations::LinkRecords` | `other_id: missing` |
| `record_links_task_pair_check` | `CHECK` | `Links::Operations::LinkRecords` | `other_id: task_pair` |
| `tags_scope_name_key` | unique | `Tags::Operations::SaveTag` | `name: taken` |
| `task_links_distinct_check` | `CHECK` | `Tasks::Operations::LinkTasks` | `other_id: self` |
| `task_links_from_task_id_fkey` | foreign key | `Tasks::Operations::LinkTasks` | `other_id: missing` |
| `task_links_pair_key` | unique index | `Tasks::Operations::LinkTasks` | `other_id: taken` |
| `task_links_to_task_id_fkey` | foreign key | `Tasks::Operations::LinkTasks` | `other_id: missing` |

Tags hold `tags_scope_name_key` since #77 split them into a public and a private scope (ADR 0074). It replaced
`tags_name_key`.

`posts_published_slug_locked` raises with `ERRCODE = 'check_violation'`, so ROM reports it as a
`CheckConstraintError` and the operation reads it like any other name. `record_links_record_missing` raises with
`ERRCODE = 'foreign_key_violation'`, so ROM reports it as a `ForeignKeyConstraintError` (ADR 0093).

Two more shapes follow the same stance. `session_validity` and `webmention_settings` hold one row each, held there
by `CHECK (id = 1)`, and their repos address it by that id. Every tag join and `tasks.sprint_id` hold their parent
with `ON DELETE RESTRICT`. `RemoveTag` counts the joins first, but only so the refusal can say how many rows hold
the parent, a count the database error drops. The foreign key stays the rule.

## Alternatives

**A contract rule with an injected repo, or the loaded row as context.** It would put every rule in one place and
return the field error with no rescue. It loses the race the context names: the check reads the row before the
write, so a post that goes live between the two passes a check that saw it scheduled.
`spec/slices/posts/requests/posts_spec.rb` pins that case: it saves from the admin editor while the locked read
hands back a stale status, and expects `slug: locked` from the trigger. A check in Ruby also binds only the callers
that run it, where the database binds every write.

## Consequences

The name is a string two files share, one in a migration and one in an operation constant. Rename the constraint
and the mapping misses, the error raises, and the form answers 500 instead of 422. Each of the fourteen names has a
spec that would fail: the posts request spec, the operation specs for decisions, record links, tags and task links,
and the admin request specs for the post and project editors. A new mapped name needs one too.

`violated_constraint` reads `error_info`, which belongs to Sequel's Postgres adapter. The repo base holds the one
reach past ROM, and moving off Postgres would break every mapping at once.

A constraint no form can break maps to nothing and raises. That is on purpose: it means a bug, not a bad entry.

`Record::Operations::SaveJournalEntry` and `UpdateJournalEntry` break the lookup. They rescue any
`CheckConstraintError` as `body: blank` and never ask for the name, so a new `CHECK` on `journal_entries` would
answer as a blank body.

The count before a delete is not atomic. A join added between the count and the delete trips the foreign key, and
nothing maps that error, so the request answers 500.

A reader cannot learn every rule from the contract. The ones over stored state are in `config/db/structure.sql`.

[0084]: 0084-keep-edit-notes-in-a-post-edits-table-and-require-one-under-the-posts-lock.md
[0099]: 0099-keep-decision-logs-in-a-decisions-slice-with-decision-events-and-a-decision-timeline-view.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
