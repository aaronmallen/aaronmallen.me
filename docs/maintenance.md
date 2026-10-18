# Maintenance

Maintenance mode takes the site down on purpose while I update Postgres, Redis or RustFS on the NAS
([ADR 0181][0181]). A file on the Pi holds the mode: while it exists, every request gets a 503 and the maintenance
page, or a JSON 503 for the API and MCP. The worker holds jobs back and Honeybadger sends no reports. The site reads the
file on each request and each job, so creating or removing it takes effect at once, with no restart.

The `maintenance.flag_path` setting names the file, through `MAINTENANCE_FLAG_PATH`. The Activate maintenance mode
button in Settings, or the same command in the palette, creates it and sets a signed cookie for my browser
([ADR 0184][0184]). A script on the Pi creates and removes it too, and still works whichever way the mode went on.

## Set up the Pi

### Name the flag file

The file belongs in the shared folder, so a deploy neither drops nor resets the mode. Add this line to
`/opt/aaronmallen.me/shared/.env`:

```sh
MAINTENANCE_FLAG_PATH=/opt/aaronmallen.me/shared/maintenance
```

Then restart both units, which read the settings once, at boot:

```sh
sudo systemctl restart aaronmallen-web aaronmallen-worker
```

Without the line, the setting falls back to `tmp/maintenance` inside the live release, which the next deploy leaves
behind.

### Let the web unit write the flag

The Activate button writes the flag from the web unit, so the unit's user needs write access to the shared folder.
Ask which user it runs as:

```sh
systemctl show --property User --value aaronmallen-web
```

If it prints your own name, or nothing (root), skip to the sandbox check. Otherwise let that user write to the
folder, and make each new file there writable by both of you, so the script can still remove or touch a flag the
button wrote:

```sh
WEB=$(systemctl show --property User --value aaronmallen-web)
sudo setfacl -m "u:$WEB:rwx" -m "d:u:$WEB:rw" -m "d:u:$USER:rw" /opt/aaronmallen.me/shared
```

Then check the unit's sandbox:

```sh
systemctl show --property ProtectSystem --value aaronmallen-web
```

If it prints `strict`, run `sudo systemctl edit aaronmallen-web`, add these lines, and restart the unit:

```ini
[Service]
ReadWritePaths=/opt/aaronmallen.me/shared
```

### Install the script

Save this as `~/.local/bin/aaronmallen-maintenance`, beside `aaronmallen-deploy`, and run
`chmod +x ~/.local/bin/aaronmallen-maintenance`. `FLAG` has to match `MAINTENANCE_FLAG_PATH`, so change both
together.

```bash
#!/usr/bin/env bash
#
# aaronmallen-maintenance on      take the site down for maintenance
# aaronmallen-maintenance off     bring the site back
# aaronmallen-maintenance status  say whether maintenance is on

set -euo pipefail

FLAG=/opt/aaronmallen.me/shared/maintenance

case "${1:-status}" in
  on) touch "$FLAG" && echo "maintenance on" ;;
  off) rm -f "$FLAG" && echo "maintenance off" ;;
  status) if [ -e "$FLAG" ]; then echo "maintenance on"; else echo "maintenance off"; fi ;;
  *) echo "usage: aaronmallen-maintenance on|off|status" >&2; exit 64 ;;
esac
```

The script lives outside the repo, as `aaronmallen-deploy` does. When the script changes here, copy it to the Pi by
hand.

## Update the NAS

1. Activate maintenance mode from Settings or the palette, or on the Pi run `aaronmallen-maintenance on`.
2. Check that `https://aaronmallen.me` answers with the maintenance page.
3. Update Postgres, Redis or RustFS on the NAS, and wait for each one to come back.
4. On the Pi, run `aaronmallen-maintenance off`.
5. Check that the site loads.

The worker skips each scheduled job it picks up while maintenance is on, since it runs again on its next tick. It puts
every other job off by five minutes, again and again, until maintenance is off.

## Don't release during maintenance

Never tag a release while maintenance is on. The deploy timer does not read the file, so it builds and restarts the
units under you, and its migrations need the database you took down. Turn maintenance off, then tag.

[0181]: adr/0181-hold-maintenance-mode-in-a-flag-file-on-the-pi.md
[0184]: adr/0184-turn-maintenance-mode-off-from-a-signed-owner-cookie-and-keep-the-admin-blocked.md
