# Backups

Each night at 00:30 the worker dumps the database with `pg_dump` and uploads the dump to a private bucket in an
S3-compatible store ([ADR 0105][0105]). It then deletes every dump past the newest 7. These notes take an empty
RustFS to working settings. Any other S3-compatible store needs the same three things: a bucket, a key that reaches
only that bucket, and the settings that name both.

The backups bucket has its own key and settings, apart from the photo store in [media-store.md](media-store.md).
Never point both at one bucket, and never reuse the photo key: a dump holds OAuth tokens, API tokens and contact
messages, and no route on the site reads from the backups bucket.

Without a bucket and both halves of a key, the site boots and the job logs that backups are not configured, then
stops. Today shows no failure for it.

## What a run does

The job names each dump for the time it ran, in UTC, such as `database-20261004T053000Z.dump`. The dump uses the
custom format, which `pg_dump` compresses and `pg_restore` reads.

When the dump or the upload fails, the job deletes nothing, records the failure where Today shows it, and raises so
Honeybadger gets it. It never retries. The next night's run tries again.

## The `pg_dump` client

The worker runs `pg_dump` on the machine it runs on, and mise does not manage it. `pg_dump` refuses to dump a
server newer than itself, so it needs a version of 17 or newer to dump Postgres 17.

On the Pi, which runs Debian, add the PostgreSQL apt repository and install the client:

```sh
sudo apt-get install --yes curl ca-certificates postgresql-common
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
sudo apt-get install --yes postgresql-client-17
pg_dump --version
```

The last line should print 17 or newer. The worker finds `pg_dump` on its `PATH`. When the version it prints
differs from the one you installed, put `/usr/lib/postgresql/17/bin` first on the worker's `PATH`.

The job connects with the database settings the site already reads, through `PGHOST`, `PGPORT`, `PGUSER`,
`PGPASSWORD` and `PGDATABASE`, so `pg_dump` needs nothing else.

## Production

The steps use `rc`, the RustFS command line client. The RustFS console does each step too. Run them from any
machine that reaches the store, with the root key RustFS started with. The first step matches the one in
[media-store.md](media-store.md), so skip it when you have named the store already.

### Name the store

```sh
rc alias set nas <endpoint> <root access key> <root secret key>
```

`<endpoint>` is the URL, with its port, that the Pi reaches RustFS at, such as `http://<nas address>:9000`.

### Make the bucket

```sh
rc mb nas/backups
```

Keep the bucket private, with no anonymous access.

### Make a key for the bucket

Write a policy that lets a key list the bucket and write and delete objects in it, and nothing else. The job lists
the bucket to find the dumps past 7. Save it as `blog-backups.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::backups"]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": ["arn:aws:s3:::backups/*"]
    }
  ]
}
```

`s3:GetObject` lets you fetch a dump back with the same key. Leave it out to keep the site's key write only.

Then load the policy, make a user for the job, and give it the policy:

```sh
rc admin policy create nas blog-backups blog-backups.json
rc admin user add nas <access key> <secret key>
rc admin policy attach nas blog-backups --user <access key>
```

Pick a long random secret, such as the output of `openssl rand -hex 32`. RustFS refuses the key every other bucket.

### Set the settings

Production reads every value from the environment. Set these where the worker runs:

| Variable | Holds |
| --- | --- |
| `BACKUP_STORE_ENDPOINT` | The `<endpoint>` from the first step. Leave it out for AWS itself. |
| `BACKUP_STORE_BUCKET` | The bucket's name, `backups`. |
| `BACKUP_STORE_ACCESS_KEY` | The access key of the user you made. |
| `BACKUP_STORE_SECRET_KEY` | Its secret key. |
| `BACKUP_STORE_PATH_STYLE` | `true` for RustFS, which wants the bucket in the path rather than the host name. It defaults to `false`. |
| `BACKUP_STORE_REGION` | The store's region. RustFS takes any, and it defaults to `us-east-1`. |

Restart the worker. It reads the settings once, at boot.

## Development

Development and test reach no backups bucket. The suite fakes the store and runs `pg_dump` against the test
database.

[0105]: adr/0105-dump-the-database-nightly-to-a-private-backups-bucket-and-keep-the-newest-7.md
