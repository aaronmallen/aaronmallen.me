---
id: "0135"
title: Find pull requests by searching GitHub for ones I authored
status: active
created: 2026-10-09
area: [record, lib]
issue: "#814"
tags: [pull-requests, github, import, search, sync]
---

# ADR 0135: Find pull requests by searching GitHub for ones I authored

![Active][status]

## Context

Spec #813 wants every pull request I author in the feed, wherever it lands, pull requests from forks into other
people's repos among them, since they leave no trace today. The commit import finds its work by walking repos
([ADR 0049][0049]), and it lists only the repos GitHub says I can push to. A pull request into a repo I cannot push
to never shows up in that list.

## Decision

The pull request import asks GitHub's search for pull requests whose author is me, across every repo. It does not
list repos or walk them. The first run reads my whole history.

## Alternatives

**Walk the repos the commit import reads** ([ADR 0049][0049]). It reuses the repo list and its edges, but that list
holds only repos I can push to, so it misses every pull request from a fork. Widening the list to every
repo I ever touched means finding those repos first, which is the same search.

## Consequences

One query finds pull requests in any repo, whether or not I can push to it, and the import keeps no edges per repo.

The import depends on GitHub's search index rather than on a repo's own history, so a pull request shows up only
once search has indexed it.

GitHub's search returns at most 1,000 results for one query, so the first run has to split my history into windows
small enough to stay under that cap.

A repo the token cannot read, or one deleted since, drops out of the results, and its pull requests with it.

[0049]: 0049-walk-each-repos-commits-in-one-job-that-queues-itself.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
