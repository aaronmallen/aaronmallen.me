---
id: "0069"
title: Read GitHub over GraphQL, and keep REST for project reads and the issue move check
status: active
created: 2026-09-29
area: [lib, record, projects, tasks]
supersedes: ["0048"]
issue: "#33"
amended: ["#941"]
tags: [github, graphql, rest, commits, issues, import, sync, rate-limit]
---

# ADR 0069: Read GitHub over GraphQL, and keep REST for project reads and the issue move check

![Active][status]

## Context

ADR 0048 moved the commit import to GraphQL and kept REST for two project reads alone. The issue sync from spec #8
broke that: #12 added a third REST read, and this record replaces ADR 0048 to say so. Every reason ADR 0048 gave
still holds, and this record carries it.

The commit import stores each commit's additions and deletions. REST's commit listing leaves them out, so the import
spent one `stats` request per commit, listed each repo's branches on their own, and fetched every commit to pick out
the owner's in Ruby. AA-311 ran one real import both ways, `aaronmallen/dotfiles`, 178 of the owner's commits on 2
branches:

| | REST | GraphQL |
| --- | --- | --- |
| Requests | 183 | 3 |
| Points | none | 3 |
| Time | 65 s | 4.2 s |

Both found the same 178 SHAs with the same line counts. GraphQL charges points per connection, not per node: a query
across 20 repos and 2,000 commit nodes cost 1 point.

The issue sync has to tell a moved issue from a deleted one, since spec #8 handles the two apart. It looks each known
issue up by GraphQL node id, and GraphQL answers with no node for either: a moved issue loses its id.

## Decision

`Record::GitHub::Client` in `lib/record/github` reads GitHub over GraphQL, and `slices/record` and `slices/tasks`
call it.

- The `COMMITS` query reads a repo's branches and the first page of each branch's history, line counts included,
  which is one chunk of the walk (AA-823).
- History filters on the author at GitHub, by node id. `history(author:)` refuses the numeric user id, so the client
  asks `viewer { id }` once and keeps it, and raises rather than ask by a null author (AA-823).
- `REPOSITORIES` sets `ownerAffiliations` beside `affiliations`. Left off, it drops every org repo with no error:
  AA-311 got 53 repos instead of 387.
- `Record::GitHub::Issues` searches the open issues assigned to the viewer, and looks up known issues by node id,
  100 at a time (#12).
- `Record::GitHub::Transport` reads the point budget from each response's `rateLimit` field, and keeps the data from
  a body whose errors are all `FORBIDDEN` or `NOT_FOUND` (AA-378).

REST serves three reads on the same token through `Record::Providers::GitHubProvider`, and a fourth on a token the
operator has not saved yet:

- `latest_release` and `stars`, which `Projects::Operations::RefreshProjects` reads. AA-378 moved the import alone,
  though AA-311 found GraphQL answers both.
- The move check. When GraphQL has no node for a known issue, the client asks REST for the issue at its stored URL.
  GitHub answers a moved issue with a 301, which the connection follows, and the answer's `html_url` names where it
  went. A 404 or 410 means the issue is gone, and `Transport#get` reads both as nothing.
- The account check. `Record::GitHub::Client#account` asks REST for `GET /user` with the candidate token, which
  `Admin::Operations::CheckService` hands it, to read the account and the scopes GitHub granted from the
  `X-OAuth-Scopes` header. #941 added this read to the list.

## Alternatives

**Stay on REST.** One request per commit for two line counts, a branch listing per repo, and an author filter in
Ruby. It lost on AA-311's numbers: 61 times the requests and 15 times the wait for the same data.

**Call every missing issue deleted.** No REST read, since GraphQL cannot tell the two apart. It lost because spec #8
names a move and a delete as separate cases, and only REST still knows the old URL.

## Consequences

The import's cost no longer tracks the number of commits, so a walk through a repo's whole history stops running
near the limit.

The app draws on two rate-limit pools, REST's requests and GraphQL's points, and the transport tracks only GraphQL's.
The project refresh and the move check learn they hit REST's limit only when a 403 or 429 raises `RateLimited`. The
move check spends one REST request per missing issue, so a run where many issues vanish at once spends many.

A 404 cannot tell a deleted issue from one the token lost access to, so an issue in a repo the operator left reads as
deleted and cancels its task. Any other failure raises, so the sync records it rather than cancel the task. The spec
for the issue queries, under `spec/slices/record/github`, pins both.

For the task, a move and a delete come out alike: the sync cancels the old task, and a moved issue still assigned
to the operator imports on its own through the search. The check decides what `task_sources` records (ADR 0068).

One chunk sees a bounded slice of a repo: `MAX_PAGES` pages of `BRANCH_PAGE_SIZE` branches, and on each branch the
first page of history. The next chunk reads on from the oldest commit it read (AA-578). Branches past the cap stay
unread.

Skipping `FORBIDDEN` and `NOT_FOUND` keeps partial data on purpose, which a reader will take for a swallowed error.
The spec for the commit job, under `spec/slices/record/jobs`, pins it.

Drop `ownerAffiliations` and GitHub says nothing: the import runs on and skips every org repo.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
