---
id: "0048"
title: Import commits over GitHub's GraphQL API and keep REST for two project reads
status: active
created: 2026-09-28
area: [lib, record, projects]
issue: AA-687
amended: [AA-793, AA-813, AA-821, AA-823]
tags: [github, graphql, rest, commits, import, rate-limit]
---

# ADR 0048: Import commits over GitHub's GraphQL API and keep REST for two project reads

![Active][status]

## Context

The commit import stores each commit's additions and deletions. REST's commit listing leaves them out, so the import
spent one `stats` request per commit on two numbers, listed each repo's branches on their own, and fetched every
commit to pick out the owner's in Ruby. Against 5,000 requests an hour, that held a walk through old commits near
4,800 commits an hour.

AA-311 ran one real import both ways, `aaronmallen/dotfiles`, 178 of the owner's commits on 2 branches:

| | REST | GraphQL |
| --- | --- | --- |
| Requests | 183 | 3 |
| Points | none | 3 |
| Time | 65 s | 4.2 s |

Both found the same 178 SHAs with the same additions and deletions. GraphQL charges points per connection, not per
node: a query across 20 repos and 2,000 commit nodes cost 1 point.

## Decision

The commit import reads GitHub over GraphQL, as AA-378 moved it. `Record::GitHub::Client` in `lib/record/github`
keeps its queries in a private `Queries` module, and `slices/record` calls the client.

- The client's `COMMITS` query reads a repo's branches and each branch's history, additions and deletions
  included, in one query: the first page of each branch, which is one chunk of the walk. AA-823 dropped
  `BRANCH_COMMITS`, which read the rest of one branch, since the next chunk reads it.
- History filters on the author at GitHub, by node id. `history(author:)` refuses the numeric user id, so
  `Record::GitHub::Client` asks `viewer { id }` once and keeps the answer. With no id in the answer, it raises
  rather than ask for history by a null author, which the query refuses (AA-823).
- `REPOSITORIES` sets `ownerAffiliations` beside `affiliations`. Left off, it falls back to owner and collaborator
  and drops every org repo with no error: AA-311 got 53 repos instead of 387.
- `Record::GitHub::Transport` reads the point budget from the `rateLimit` field of each response body, where
  GraphQL reports it.
- The transport keeps the data from a GraphQL body whose errors are all `FORBIDDEN` or `NOT_FOUND`. A repo the token
  cannot read, or a branch gone between pages, then reads as no commits rather than failing the run, as REST's 404
  and 409 did (AA-378).

REST stays for `latest_release` and `stars`, which `Projects::Operations::RefreshProjects` reads. AA-378 moved the
import alone, though AA-311 found GraphQL answers both. `Record::Providers::GitHubProvider` builds both connections
on one token.

## Alternatives

**Stay on REST.** One request per commit for two line counts, a branch listing per repo, and an author filter in
Ruby over every commit fetched. It lost on AA-311's numbers: 61 times the requests and 15 times the wait for the
same data.

## Consequences

The import's cost no longer tracks the number of commits, so a walk through a repository's whole history stops
running near the limit.

Two connections share one token, and the app draws on two rate-limit pools, REST's requests and GraphQL's points.
The transport tracks only the GraphQL pool. `get` keeps no count of REST's budget, so the project refresh learns it
hit REST's limit only when a 403 or 429 raises `RateLimited`.

One chunk sees a bounded slice of a repo: `MAX_PAGES` pages of `BRANCH_PAGE_SIZE` branches, and on each branch the
first page of history. The next chunk reads on from the oldest commit it read (AA-578). Branches past the listing
cap stay unread in every chunk.

Skipping `FORBIDDEN` and `NOT_FOUND` keeps partial data on purpose, which a reader will take for a swallowed error.
The spec for the job that reads a repository's commits, under `spec/slices/record/jobs`, pins it: the job stores
nothing and records no failure for a repository GitHub answers with either, and keeps what it read from a branch
listing that goes mid-read.

Drop `ownerAffiliations` and GitHub says nothing: the import runs on and skips every org repo.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
