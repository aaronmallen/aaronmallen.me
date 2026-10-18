# Deploy

The site runs on a Raspberry Pi and builds each new tag there ([ADR 0006][0006]). This page lists what the repo
assumes of the Pi. None of it lives in the repo, so when a release changes any of it, do the change on the Pi by hand
before you tag. [Releasing](releasing.md) has the step.

## Units

Two systemd units run the site, both as the user that owns `/opt/aaronmallen.me/shared`:

| Unit | Runs |
| --- | --- |
| `aaronmallen-web` | Puma |
| `aaronmallen-worker` | Sidekiq, with `HANAMI_ENV=production` and `MALLOC_ARENA_MAX=2` |

Neither sets `ProtectSystem` or `PrivateTmp`, so both write where their user may and share the Pi's `/tmp`. Each
reads its settings once, at boot, so restart both after you change one:

```sh
sudo systemctl restart aaronmallen-web aaronmallen-worker
```

`cloudflared` runs the tunnel that serves the blog and `aa.cool` ([Shares](shares.md)).

## Packages

mise manages none of these. Install each by hand over SSH:

| Package | For | Detail |
| --- | --- | --- |
| `git` | The version the app reads from its tag | [ADR 0073][0073] |
| `libvips42t64`, `libheif-plugin-libde265` | Every photo upload. Without libvips the site does not start. | [Media store](media-store.md) |
| `postgresql-client-18` | The nightly database dump and restores | [Backups](backups.md) |
| `cloudflared` | The tunnel | [Shares](shares.md) |

## Shared paths

Every release reads these, and no deploy drops or resets them:

| Path | Holds | Detail |
| --- | --- | --- |
| `/opt/aaronmallen.me/shared/.env` | Every setting production reads from the environment | [The env file](#the-env-file) |
| `/opt/aaronmallen.me/shared/maintenance` | The maintenance flag, while maintenance is on | [Maintenance](maintenance.md) |
| `/opt/aaronmallen.me/shared/tmp` | The worker's `TMPDIR`, for database dumps | [Backups](backups.md) |
| `MAXMIND_DATABASE_PATH` | The MaxMind country database, in a folder the releases share | [ADR 0006][0006] |

The Pi's `/tmp` lives in RAM, capped at about half of memory, which is why the worker needs a `TMPDIR` on disk.

## The env file

`/opt/aaronmallen.me/shared/.env` holds the secrets and every value production takes from the environment.
`.env.example` lists each variable and its default. Production needs these beyond what a laptop does:

- `REDIS_PORT`, since the NAS Redis does not listen on the default ([ADR 0006][0006]).
- `HONEYBADGER_API_KEY`, which the deploy reads too, to report each release.
- The store settings in [Media store](media-store.md), [Backups](backups.md) and [Shares](shares.md).

Each `HONEYBADGER_CHECK_IN_*` is optional. Set one only for a scheduled job you want Honeybadger to watch, naming a
check-in you made for its schedule in `config/sidekiq.yml.erb`. Leave it unset otherwise; the job runs the same.

`mise run release --dry-run` prints each variable `.env.example` gained since the last tag.

## The deploy script

`~/.local/bin/aaronmallen-deploy` lives on the Pi, not in the repo. A timer runs it, and when it sees a new tag it:

1. Clones the tag with `git clone --depth 1 --branch <tag>` into a release folder of its own, keeping `.git`, or the
  app reads its version as `unknown` ([ADR 0073][0073]).
2. Builds the CSS from `config/tailwind/public.css` and `config/tailwind/admin.css`.
3. Migrates with `hanami db migrate`. `mise run db:migrate` starts a local Postgres first, so the deploy never calls
  it ([ADR 0006][0006]).
4. Points `current` at the release and restarts both units.
5. Reports the tag to Honeybadger.

A change to how the app builds, such as a new Tailwind entry point, needs the same change in the script.

## Scripts kept outside the repo

| Script | Detail |
| --- | --- |
| `~/.local/bin/aaronmallen-deploy` | [The deploy script](#the-deploy-script) |
| `~/.local/bin/aaronmallen-maintenance` | [Maintenance](maintenance.md) holds its source. Copy it to the Pi when that changes. |

[0006]: adr/0006-run-the-site-on-a-raspberry-pi-behind-a-cloudflare-tunnel-with-its-data-on-the-nas.md
[0073]: adr/0073-read-the-app-version-from-the-git-tag-at-boot.md
