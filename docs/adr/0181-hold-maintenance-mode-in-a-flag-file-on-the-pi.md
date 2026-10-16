---
id: "0181"
title: Hold maintenance mode in a flag file on the Pi
status: active
created: 2026-10-16
area: [app, config, lib]
issue: "#1584"
tags: [maintenance, flag-file, settings, deploy, pi, nas, sidekiq, honeybadger, postgres, redis, rustfs]
---

# ADR 0181: Hold maintenance mode in a flag file on the Pi

![Active][status]

## Context

Postgres, Redis and RustFS run on the NAS, and the site runs on the Pi. When I update one of them on the NAS, the Pi
keeps serving: visitors get 500 pages, scheduled jobs fail and Honeybadger fills with errors. Spec #1584 adds a
maintenance mode I turn on from the Pi before the update and off after it.

Whatever holds the mode has to answer while all three NAS stores are down. Both Puma workers and the Sidekiq worker
have to read it, and a change has to reach them with no restart.

## Decision

**A file on the Pi holds maintenance mode: present means on, absent means off.** A new setting names its path, in
the shared folder that outlives each release, so a deploy neither drops nor resets the mode.

Three readers check the file each time they need the answer, never caching it, so removing the file ends maintenance
at once:

- The web check, ahead of every request, the share host included, answers 503 before anything touches the NAS.
- The Sidekiq worker skips jobs while the file exists.
- The Honeybadger provider ([ADR 0010][0010]) sends no reports while the file exists.

A script on the Pi, in `~/.local/bin/` beside `aaronmallen-deploy` and outside the repo, creates and removes the
file. The app only reads it.

## Alternatives

**A row in Postgres or a key in Redis.** Both live on the NAS, so neither can be read during the outage the mode
covers. [ADR 0020][0020] already keeps locks and claims out of Redis.

**A maintenance page set in Cloudflare.** Turning it on would need a call out from the Pi, and it would cover only
the web. The worker and Honeybadger would not know, so jobs would still fail and errors would still report.

## Consequences

The mode needs no store but the Pi's own disk, and turning it on or off takes a file and no deploy.

Each request and each job reads the disk once more. A missing file costs a failed `stat`, which is cheap, but every
request pays it.

The mode lives on one machine. If the site ever runs on a second host, each one needs its own file, or the mode
moves to a store both can reach.

The script lives outside the repo, as `aaronmallen-deploy` does, so a change to the setting's path has to reach the
Pi by hand.

[0010]: 0010-configure-honeybadger-from-settings-in-a-provider-not-from-honeybadger-yml.md
[0020]: 0020-keep-locks-throttles-and-claims-in-postgres-not-redis.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
