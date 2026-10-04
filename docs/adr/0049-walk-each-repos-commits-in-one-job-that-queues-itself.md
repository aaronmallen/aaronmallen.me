---
id: "0049"
title: Walk each repo's commits in one job that queues itself
status: active
created: 2026-09-28
area: [config, lib, record]
issue: AA-684
amended: [AA-758, AA-821, AA-823, "#248"]
tags: [commits, github, sync, walk, sidekiq, rate-limit, sync-states]
---

# ADR 0049: Walk each repo's commits in one job that queues itself

![Active][status]

## Context

The commit import once ran as one job over every repository and wrote one `commits` timestamp at the end. A rate
limit halfway through threw the whole run away, and the next run did it all again (AA-304). The import also read
only 30 days back, so nothing older ever arrived, and a walk through the rest had to share GitHub's point budget
with the sync that feeds Today without starving it (AA-310).

Each fix since has stopped an edge claiming more than the code read, or bounded the walk: a watermark set when jobs were
queued rather than run (AA-500), a forward edge set past an unread page, an empty page that moved the edge one
second (AA-532), a branch cut short at the page cap (AA-578), a commit pushed after a later run had moved the edge
(AA-614), and a walk with no floor (AA-553).

That left two jobs over the same repositories, each with its own edges: a 15-minute import that read forward from
a global watermark, and a backfill that walked back only after somebody pressed a button in the admin. A fresh
database showed one month of work until then, and only the backfill held back part of the rate limit (AA-820).

## Decision

One job walks a repository's commits, and one finder queues it. Each repository holds its own edges in
`sync_states`, and each edge moves only as far as the code read. `Record::Repos::CommitRepo` owns them. Each row is
named by its `kind`, and `<repo>` stands for its `repo` column (AA-758); ADR 0047 covers the table.

`Record::Operations::ImportCommits` is the finder, and runs every 15 minutes. Its floor is the newest row in
`commits`, minus one day. The newest row is the one stored last, by `created_at`, so a commit dated ahead of the
clock cannot lift the floor (AA-823). It lists the repositories GitHub says were pushed since that floor, by push
time, never by commit dates, and every repository when `commits` is empty. It adds every repository with a failure
recorded for the `commits` sync, pushed or not, skips any whose walk is still going, and queues one walk for each
of the rest.

`Record::Jobs::BackfillRepoCommits` is the walk. The finder starts one by setting its back edge to the finder's
own clock and passing that clock to the job, which hands it on to every chunk it queues. The walk reads back:

- `commits:<repo>` is the forward edge, and the walk's floor. A repository with none walks to the start of its
  history, and a step past its creation date ends the walk there. Reaching the floor, or a step that would pass
  it, starts the sweep below it.
- The sweep reads under the floor with no lower bound. GitHub filters history by commit date, not push date, so a
  branch pushed days after its commits holds history under the floor that no walk has read (#248). A branch is
  done once its page holds a commit already stored, reads to its end or comes back empty. A chunk with every
  branch done moves the forward edge to a day before the walk began (`Record::CommitEdge::OVERLAP`), and the walk
  ends. Otherwise the back edge moves down the branches still open, and the next chunk sweeps on from there. A back
  edge at or under the floor marks a walk as sweeping.
- `backfill:<repo>` is the back edge, where the walk has read down to. It lives only while a walk is going.

AA-823 settled how the finder tells a walk is going: its back edge exists, and a chunk has touched the row's
`updated_at` in the last two hours (`ImportCommits::STALLED_AFTER`). Every chunk touches it first, even one that
stops for the rate limit, and a reset is at most an hour off, so a going walk never looks stalled. A walk whose job
died, from an exception past its retries or a worker killed mid-chunk, stops touching the row. Once it has sat two
hours, the finder starts the walk again at a new clock, pushed or not.

A chunk reads one page per branch, stores what it found, moves the back edge, and queues itself again. Under 1,000
points left it stops and queues itself for the reset. A chunk that read nothing steps back an hour
(`Record::CommitEdge::EMPTY_STEP`). A walk that ends at the creation date with a branch never read to the end
records a failure for the `commits` sync with the reason `repository_start` that names the branches. A chunk GitHub
answers with an error records a failure for the `commits` sync with GitHub's message, drops the back edge and queues
nothing, so the finder's next run starts a fresh walk (AA-823). The client refuses to read history when GitHub
sends no viewer id, rather than ask for commits by a null author, and that counts as the same error.

## Alternatives

**One timestamp per repository** (AA-304). It cannot say how far back a repository has filled, so a walk into the
past would have needed a new shape.

**One job over every repository** (AA-304). A rate limit anywhere cost the whole run.

**A global watermark row the import moves.** It had to wait for every repository it queued, so one stalled
repository pinned it, and each run then listed every repository pushed since that edge. A repository with more
branches than one run reads never moved its edge, and kept the watermark there for good. The newest row in
`commits` says only what the code stored, so it cannot claim more than was read.

**Move the watermark when the jobs are queued** (AA-500). A repository whose job ran out of retries fell out of
the next window and waited for somebody to push to it. The finder now picks up every repository with a recorded
failure, whether anybody pushed to it or not.

**Mark where a read stopped at the page cap** (`unread:<repo>`, AA-578). The import read up to `MAX_PAGES` pages
of a branch and marked where the cap cut it, so the next run could read below the mark. A chunk reads one page
per branch, and its back edge already marks where it stopped. The one cap left, the branch listing, cuts the same
branches off every read, so no later walk could read below such a mark. AA-823 dropped it.

**Resume a failed walk from its back edge.** It saves reading again what the failed walk had read, but the walk
would then need its first clock and the finder a second signal for a walk that stopped rather than stalled. A chunk
costs a point or two, so a fresh walk from the top costs little.

**A backfill the operator starts from the admin.** It left a fresh database with one month of history until
somebody pressed the button, kept a second set of edges for the same repositories, and let the 15-minute import
spend the points the backfill held back. One walk that reads to its forward edge covers both jobs.

**Backfill in one long run** (AA-310). Stopping it anywhere loses the run, and it competes with the daily sync for
the budget.

**A set limit on how far back a walk goes** (AA-553). The creation date is the honest floor: nothing can be
committed before it.

## Consequences

**A fresh database fills on its own**, and the first run queues a walk for every repository, which then holds the
queue for as many chunks as the history takes.

**A quiet stretch widens the finder's window.** The floor follows the newest commit, not the clock, so after a
month without one every run lists a month of pushes and walks each repository in it again. Each of those walks
reads only down to its forward edge.

**The forward edge trails the walk by a day**, so every walk reads that day again to catch a late push. The
`commits` upsert keys on the sha, so a commit read twice stays one row.

**A gap in history costs one chunk per hour of it**, since an empty chunk can only step back an hour.

**A grounded repository counts as failed**, so the next run walks it again. That walk reads only down to the
forward edge, so it clears the failure without reading the grounded branches.

**Branches past the listing cap go unread, and unreported.** A chunk lists `MAX_PAGES` pages of ten branches.
Every chunk of every walk lists the same ones, so the rest of a repository with more branches never arrives, and
Today says nothing about it.

**A push during a long walk can be missed.** The finder skips a repository while its walk is going, and that walk
reads only below its own clock. The push waits for the next run, and the one-day overlap covers it unless other
walks store newer commits for more than a day first, as a first fill on an empty table can. It then waits for the
next push to that repository.

**Every walk with a floor costs one more read**, the sweep's first page under it. A branch whose new commits run
past a page keeps the sweep going a chunk per page.

**A walk GitHub fails starts over** from its new clock and reads again what the failed one had read, since a
failure drops the back edge.

**Today's last sync is when a walk last reached its floor**, the newest `updated_at` among the forward edges, not
the edge itself, which trails by a day.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
