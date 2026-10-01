# Media store

The site keeps photos in an S3-compatible store ([ADR 0080][0080]). These notes take an empty RustFS to working
settings. Any other S3-compatible store needs the same three things: a bucket, a key that reaches only that bucket,
and the settings that name both.

Without a bucket and both halves of a key, the site boots and takes no uploads.

## Development

`mise run dev` starts RustFS from `.config/compose.yml` and makes the `blog-development` bucket in it.
`mise run setup:environment` writes the root key to `.env` as `MEDIA_STORE_ACCESS_KEY` and
`MEDIA_STORE_SECRET_KEY`, and `config/settings/development.yml` points the app at it, so a laptop needs none of the
steps below. The suite fakes the store and never reaches one.

## Production

The steps use `rc`, the RustFS command line client. The RustFS console does each step too. Run them from any
machine that reaches the store, with the root key RustFS started with.

### Name the store

```sh
rc alias set nas <endpoint> <root access key> <root secret key>
```

`<endpoint>` is the URL, with its port, that the Pi reaches RustFS at, such as `http://<nas address>:9000`.

### Make the bucket

```sh
rc mb nas/<bucket>
```

Keep the bucket private. The site fetches each photo itself and serves it under its own name, so no reader ever
reaches the store.

### Make a key for the bucket

Write a policy that lets a key read, write and delete objects in that bucket and nothing else. Save it as
`blog-photos.json`, with your bucket's name in place of `<bucket>`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": ["arn:aws:s3:::<bucket>/*"]
    }
  ]
}
```

Then load the policy, make a user for the site, and give it the policy:

```sh
rc admin policy create nas blog-photos blog-photos.json
rc admin user add nas <access key> <secret key>
rc admin policy attach nas blog-photos --user <access key>
```

Pick a long random secret, such as the output of `openssl rand -hex 32`. The key can now put, read and delete
photos in the bucket, and RustFS refuses it everything else, listing buckets included.

### Set the settings

Production reads every value from the environment. Set these where the site runs:

| Variable | Holds |
| --- | --- |
| `MEDIA_STORE_ENDPOINT` | The `<endpoint>` from the first step. Leave it out for AWS itself. |
| `MEDIA_STORE_BUCKET` | The bucket's name. |
| `MEDIA_STORE_ACCESS_KEY` | The access key of the user you made. |
| `MEDIA_STORE_SECRET_KEY` | Its secret key. |
| `MEDIA_STORE_PATH_STYLE` | `true` for RustFS, which wants the bucket in the path rather than the host name. It defaults to `false`. |
| `MEDIA_STORE_REGION` | The store's region. RustFS takes any, and it defaults to `us-east-1`. |

Restart the web process and the worker. Each reads the settings once, at boot.

[0080]: adr/0080-store-photos-in-an-s3-store-and-serve-them-through-the-site.md
