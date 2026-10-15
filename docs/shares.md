# Shares

The site hands out files by short link on `aa.cool`, such as `https://aa.cool/k7mq2` ([ADR 0141][0141]). The Pi
serves `aa.cool` from the same process as the blog, and `.config/config.ru` sends each request to the shares app or
the blog by its host ([ADR 0142][0142]). These notes take `aa.cool` from a bare domain to working shares: the
Cloudflare zone, the tunnel hostname rule, the bucket and the production settings.

## Development

`mise run dev` makes the `shares-development` bucket in the local RustFS, and `config/settings/development.yml`
serves shares at `http://shares.localhost:2300`, so a laptop needs none of the steps below. The suite fakes the store
and never reaches one.

## Production

### Add the zone

Add `aa.cool` to Cloudflare as a zone of its own, on the free plan, and point the registrar at the nameservers
Cloudflare names. The zone is active once Cloudflare reports it so.

Add no cache rules to it. See [Caching](#caching).

### Route the host through the tunnel

The tunnel that serves the blog, `aaronmallen-me`, serves `aa.cool` too. On the Pi, add a hostname rule to
`/etc/cloudflared/config.yml` that points at the same service as the blog, above the 404 catch-all:

```yaml
ingress:
  - hostname: aaronmallen.me
    service: http://127.0.0.1:2300
  - hostname: aa.cool
    service: http://127.0.0.1:2300
  - service: http_status:404
```

Check the file, then restart `cloudflared` so it reads the rule:

```sh
cloudflared tunnel ingress validate
cloudflared tunnel ingress rule https://aa.cool
sudo systemctl restart cloudflared
```

The second command should name `http://127.0.0.1:2300`.

Then add the DNS record that sends `aa.cool` to the tunnel:

```sh
cloudflared tunnel route dns aaronmallen-me aa.cool
```

Check the record under DNS in the `aa.cool` zone. It should be a proxied `CNAME` for `aa.cool` that points at
`<tunnel id>.cfargotunnel.com`. `cloudflared` writes the record into the zone it logged in to, so when the record
shows up as `aa.cool.aaronmallen.me` instead, delete it and add the `CNAME` by hand in the `aa.cool` zone.

### Make the bucket

The steps use `rc`, the RustFS command line client, through the `nas` alias that [media-store.md](media-store.md)
sets up. Name the store first as that page says, if you have not.

```sh
rc bucket create nas/aa.cool
rc bucket list nas
```

`aa.cool` should show beside the media bucket. To check it takes a file, put one, read it back and take it off:

```sh
echo "check" > rc-check.txt
rc put rc-check.txt nas/aa.cool/rc-check.txt
rc object show nas/aa.cool/rc-check.txt
rc object remove nas/aa.cool/rc-check.txt
```

Keep the bucket private. Anyone with a link may read a share, but the site streams each one itself, so no reader
ever reaches the store.

### Make a key for the bucket

Write a policy that lets a key read, write and delete objects in the bucket and nothing else. Save it as
`blog-shares.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": ["arn:aws:s3:::aa.cool/*"]
    }
  ]
}
```

Then load the policy, make a user for the site, and give it the policy:

```sh
rc admin policy create nas blog-shares blog-shares.json
rc admin user add nas <access key> <secret key>
rc admin policy attach nas blog-shares --user <access key>
```

Pick a long random secret, such as the output of `openssl rand -hex 32`. Never reuse the photo key: the media bucket
holds photos no visitor may see.

### Set the settings

`config/settings/production.yml` names the bucket, `aa.cool`, and the share host, `https://aa.cool`, so neither
comes from the environment. Set the rest in the shared `.env` on the Pi:

| Variable | Holds |
| --- | --- |
| `SHARE_STORE_ENDPOINT` | The `<endpoint>` the `nas` alias names. Leave it out for AWS itself. |
| `SHARE_STORE_ACCESS_KEY` | The access key of the user you made. |
| `SHARE_STORE_SECRET_KEY` | Its secret key. |
| `SHARE_STORE_PATH_STYLE` | `true` for RustFS, which wants the bucket in the path rather than the host name. It defaults to `false`. |
| `SHARE_STORE_REGION` | The store's region. RustFS takes any, and it defaults to `us-east-1`. |
| `SHARE_STORE_READ_TIMEOUT` | How many seconds to wait for the store to answer. It defaults to `300`. |
| `SHARE_TRANSFERS` | How many downloads and zips each web worker streams at once. Past it the share host answers `503`. It defaults to two under `HANAMI_MAX_THREADS`, and never under one. |

Restart the web process. It reads the settings once, at boot. Without both halves of the key, the site boots and
takes no shares.

### Check it

Upload a file under Files in the admin, open its link, and check the headers:

```sh
curl -sI https://aa.cool/<code>
```

The answer should carry `cache-control: private, no-store` and `cf-cache-status: DYNAMIC`. Request it again: it
should still say `DYNAMIC`, never `HIT`.

## Caching

The app sends `private, no-store` on every answer from the share host, a share, a short link redirect and a 404
alike, so no cache keeps one ([ADR 0142][0142]). Each download reaches the app and counts.

The cache rules of [ADR 0090][0090] do not reach `aa.cool`. Cloudflare keeps cache rules per zone, and both rules
live on the blog's zone. The first matches only the blog's host, and the second, which skips the cache for the
`admin.session` and `site_theme` cookies, has nothing to skip on `aa.cool`, where no page sets either. The new zone
starts with no rules, and needs none: `no-store` keeps Cloudflare from storing an answer whatever a later rule asks.
Add no rule that sets an edge TTL on `aa.cool`, since one that overrides the origin would keep shares and break the
count.

## Upload limit

Cloudflare's free plan refuses a request body over 100 MB through the tunnel, with a `413`. You upload a file
through the admin, on the blog's host, so a share over 100 MB cannot reach the site. Nothing works around this.

[0090]: adr/0090-let-cloudflare-keep-anonymous-public-pages-for-five-minutes.md
[0141]: adr/0141-keep-file-shares-in-a-shares-slice-with-their-own-public-bucket.md
[0142]: adr/0142-serve-shares-on-their-own-host-picked-in-config-ru-and-let-no-cache-keep-them.md
