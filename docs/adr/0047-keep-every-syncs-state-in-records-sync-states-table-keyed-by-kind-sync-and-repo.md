---
id: "0047"
title: Keep every sync's state in record's sync_states table, keyed by kind, sync and repo
status: active
created: 2026-09-28
area: [admin, analytics, db, projects, record]
issue: AA-688
amended: [AA-821, AA-823, "#941"]
tags: [sync-states, sync, failures, today, schema, postgres, slices, exports]
---

# ADR 0047: Keep every sync's state in record's sync_states table, keyed by kind, sync and repo

![Active][status]

## Context

Four syncs run in the worker: the commit import, the analytics rollup, the country file refresh and the project
refresh. Each has to leave its outcome where Today can read it. AA-308 asked for that for the two GitHub syncs and
said to build it once. AA-550 put the rollup on the same shape. AA-488 kept a commit failure per repository, so one
repository's success cannot clear another's. AA-534 split a failure's bounded reason from its message and left that
per-repository key alone. The commit import keeps its edges and marks in the same table, as the record on the commit
walk sets out.

`config/db/migrate/20260928000018_create_sync_states.rb` gives `sync_states` one text primary key, `name`, and no
column for the kind, the sync or the repository. The name packs all three: `commits:<repo>`, `backfill:<repo>`,
`failure:<sync>:<repo>`. AA-304 chose that because a row per repository needed no migration. That counts for
nothing before deploy, since we edit the original migration in place.

The packing costs code. `Record::Repos::CommitRepo` and `Record::Repos::SyncStateRepo` split the table by prefix,
and a comment above `CommitRepo` has to say which names belong to which. Reads scan with `LIKE`
(`Record::Relations::SyncStates#prefixed`), and each repo cuts the name apart again, in `CommitRepo#edges` and
`SyncStateRepo#to_failure`.

Record holds three other slices' health as well. `SyncStateRepo` names `analytics_rollup`,
`country_database` and `projects` beside `commits`. Record exports `record_country_sync_outcome`,
`record_projects_sync_outcome` and `record_rollup_sync_outcome`, and `analytics` and `projects` import them.

## Decision

`sync_states` stays one table in `record` and holds every sync's edges, marks and failures. Three columns take the
place of `name`, under one unique index: `kind`, `sync` and `repo`. We edit the original migration to say so.

- `kind` says what the row is, and takes what the first part of the name holds today.
- `sync` names the failing sync on a failure row, and stays empty on every other row.
- `repo` names the repository on a row kept per repository, and stays empty otherwise.

`kind` and `sync` hold closed sets, so each takes a Postgres enum, as the record on enums asks. The index sets
`nulls_distinct: false`, as the rollup tables' indexes do, so a row with no sync or no repository is still one row.

| `kind` | `sync` | `repo` | Owner | The row holds |
| --- | --- | --- | --- | --- |
| `commits` | | set | `CommitMutations` | A repository's forward edge |
| `backfill` | | set | `CommitMutations` | Where a walk that is going has read down to, and when a chunk last touched it |
| `failure` | a `sync_name` | set or empty | `SyncStateMutations` | Why the sync last failed |

`SyncStateMutations` also owns the four failure columns, and `SyncStateQueries` reads them. Neither commit repo
reads or writes the failure rows, and neither sync state repo touches the commit rows. Each picks rows by equal
columns and reads the sync and the repository from their own columns. #941 corrected these repo names from
`CommitRepo` and `SyncStateRepo`.

Another slice writes its health only through record's exports. A new sync takes an enum value, matched in
`Blog::Types::SyncName`, an import of `record.operations.record_sync_outcome` in the slice that runs it (#941 corrected
this from one `record_*_sync_outcome` export per sync), and, if it fails per repository, an entry in
`Record::Operations::ReapSyncStates::SYNCS` so the reaper drops rows for repositories that are gone.

## Alternatives

**Keep the kind, the sync and the repository packed into a text name** (AA-304). It lost because the prefix
parsing spread across `CommitRepo` and `SyncStateRepo`: each builds names, scans by prefix and cuts names apart,
and a comment has to hold the line between them. Its one gain, no migration, does not apply before deploy.

**A health table per slice, with a query Today reads.** Each slice would own its failures outright, the way the record
on slices has each slice own its tables. It lost to AA-308's rule to build the failure record once, which AA-550 held
the rollup to: one table gives Today one query, `record.repos.sync_state_queries` (#941), where a table per slice means
one more table and one more query for every slice that syncs.

## Consequences

A row says what it is in its columns. No code builds a name or splits one, no read scans with `LIKE`, and the
comment that divides the table goes.

A new kind or sync is a schema change: an enum value in the migration, kept in step with `Blog::Types::SyncName` and
`Blog::Types::SyncStateKind` by hand (#941). After deploy that is `ALTER TYPE ... ADD VALUE`.

Record holds other slices' health, so `analytics` and `projects` depend on it to report their own failures, and a
new sync touches record, the slice that runs it, and the migration.

The country file's health does not fit. It comes from the file on disk, not from a run, so
`Admin::Operations::SummarizeToday` reads `analytics.repos.country_queries#database_failure` and builds a
`countries` failure by hand beside the rows. A refresh run fits: `Analytics::Jobs::RefreshCountryDatabase` records
its outcome as a `country_database` failure row through `record_sync_outcome` (#941).

Editing the original migration means every local database drops and builds again to pick it up.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
