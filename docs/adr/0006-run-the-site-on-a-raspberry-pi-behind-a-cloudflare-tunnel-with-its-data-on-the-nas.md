---
id: "0006"
title: Run the site on a Raspberry Pi behind a Cloudflare Tunnel, with its data on the NAS
status: active
created: 2026-09-28
area: [config]
issue: AA-277
amended: ["#63", "#132", "#396"]
tags: [deploy, raspberry-pi, cloudflare, tunnel, nas, postgres, redis, s3, systemd]
---

# ADR 0006: Run the site on a Raspberry Pi behind a Cloudflare Tunnel, with its data on the NAS

![Active][status]

## Context

The site has never run anywhere but a laptop, and parts of it cannot work until it does. Bridgy needs a live
webmention endpoint, GitHub sign-in needs a callback on a real host, the MCP server needs a URL a client can reach,
and analytics needs visitors.

We already have Postgres and Redis on the NAS, a spare Raspberry Pi 5 with 16GB, and the domain on Cloudflare. The
schema needs Postgres 15 or newer for `NULLS NOT DISTINCT` and `regexp_count`. High availability, surviving a power
cut, more than one region and moving DNS off Cloudflare are out of scope. AA-277 weighed the options and settled
them on 2026-09-18.

## Decision

The site runs on the Pi in the office and Cloudflare publishes it through a tunnel on a subdomain.

- Puma and Sidekiq run on the Pi as systemd units, with no containers and no registry.
- Postgres and Redis stay on the NAS, one hop away on the LAN.
- Photos sit in an S3 store on the NAS, a fact #132 added. It has no public route, so the Pi fetches each photo
  and serves it, as [ADR 0080][0080] says.
- A nightly dump of the database sits in a private `backups` bucket in the same store, a fact #396 added. The site
  makes the dump and keeps the newest 7, as [ADR 0105][0105] says.
- The tunnel connects out from the Pi, so no port opens on the home network and Cloudflare ends TLS.
- The Pi builds its own releases. A timer sees a new git tag, builds it in its own release directory while the old
  one serves, migrates, points `current` at it and restarts both units. Rolling back points `current` back.
- After it restarts the units, a deploy or a rollback reports the live tag to Honeybadger, a step #63 added. It
  posts to `https://api.honeybadger.io/v1/deploys` with `HONEYBADGER_API_KEY` from the shared `.env`, and names the
  tag as the revision, `production` as the environment, the repository and the Pi user. A report that fails logs a
  warning and the deploy goes on, since the release is already live.

The code follows from this. `config/settings/production.yml` reads the visitor address from `CF-Connecting-IP` and
trusts only the loopback, where `cloudflared` connects. `config/puma.rb` listens on the loopback by default. Only
`production.yml` reads `DATABASE_HOST` and `REDIS_HOST`, so development and test stay on localhost.

## Alternatives

**Fly.io, with Postgres and Redis there too.** The site stops going down with the house, and a deploy is one
command. With managed Postgres it costs about $60 a month. Fly's own Postgres brings that to about $24, but then the
backups and the recovery are ours, which is what a managed database was meant to buy. Fly.io stays the fallback if
the Pi turns into a hobby.

**Fly.io, reaching the NAS over Tailscale.** Every page runs several queries across the home uplink, at 20 to 40ms
each, so a page waits a third of a second on its queries. It still goes down with the house, and it adds a Tailscale
sidecar and its keys to the deploy.

**Everything on the Pi, Postgres included.** One box, but the database then sits on the Pi's own storage, with
worse backups and a less reliable disk than the NAS.

**Deploys pushed from GitHub Actions over SSH, or Kamal.** Both push into the house, which means opening the way in
that the tunnel exists to close. A self-hosted runner on the Pi is worse: on a public repo, a fork's pull request
runs its code inside the home network.

## Consequences

When the house loses power or internet, the site goes down. We chose that.

Postgres connections have a budget. Each process sizes its pool at its threads plus one, capped by
`DATABASE_MAX_CONNECTIONS`, so at the defaults the worker opens 11 and the web process 6. `HANAMI_WEB_CONCURRENCY`
above 1 forks Puma, and each fork opens its own pool. The total has to stay inside the NAS Postgres
`max_connections`.

Redis on the NAS listens on port 30059. The settings fall back to 6379, so the deploy must set `REDIS_PORT` or the
worker cannot connect. The NAS runs Postgres 17, which clears the schema's floor.

After a power cut the Pi and the NAS come back in any order, so the units must retry until the NAS answers rather
than give up at boot.

`mise run db:migrate` starts a local Postgres container first (`scripts/util/ensure_postgres`), so the deploy has to
call `hanami db migrate` itself. The MaxMind database sits in `tmp/maxmind` under the release root
(`lib/analytics/providers/geo_provider.rb`), so each release starts without it until AA-307 moves it to a directory
the releases share.

[0080]: 0080-store-photos-in-an-s3-store-and-serve-them-through-the-site.md
[0105]: 0105-dump-the-database-nightly-to-a-private-backups-bucket-and-keep-the-newest-7.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
