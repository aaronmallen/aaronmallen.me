# aaronmallen.me

My personal website and blog, live at [aaronmallen.me]: the public blog, an admin behind GitHub sign in, and an
MCP server. It is a [Hanami] app on Postgres, with Sidekiq jobs on Redis.

## Setup

You need [mise] and Docker. mise installs Ruby and every other tool, and runs each task below. Docker runs Postgres,
Redis and RustFS from `.config/compose.yml`.

```sh
mise trust
mise run setup
```

`mise run setup` writes `.env` with the values it can fill in on its own, installs the gems, node packages and libvips
when Ruby cannot load it, and prepares the development and test databases. To sign in to the admin, add a GitHub OAuth
app's pair to `.env`, as `.env.example` says. `.env.example` lists every other variable the app reads.

## Development

```sh
mise run dev
```

It starts Postgres, Redis and RustFS, then the server, the worker and the asset watchers. The site answers at
`http://localhost:2300`. `mise run dev:stop` stops it all.

`mise run db:migrate` migrates the database and dumps the schema to `config/db/structure.sql`. `mise tasks` lists
the rest.

## Tests

```sh
mise run test
mise run lint
mise run format
```

`mise run test` builds the assets, starts Postgres if it is down, then runs the suite.
`mise run test:browser` runs the browser specs alone.

## Docs

- [Backups](docs/backups.md): the nightly database dumps and how to restore one.
- [Maintenance](docs/maintenance.md): taking the site down for a NAS update and bringing it back.
- [Media store](docs/media-store.md): the photo bucket, its key and libvips.
- [Releasing](docs/releasing.md): the steps to tag and ship a version.
- [Shares](docs/shares.md): the short links on `aa.cool`.
- [Writing ADRs](docs/writing-adrs.md): how to write and change a decision record.
- [Decision records](docs/adr): every decision behind the code.

[aaronmallen.me]: https://aaronmallen.me
[Hanami]: https://hanamirb.org
[mise]: https://mise.jdx.dev
