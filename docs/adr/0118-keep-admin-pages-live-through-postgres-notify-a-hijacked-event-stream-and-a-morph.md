---
id: "0118"
title: Keep admin pages live through Postgres notify, a hijacked event stream and a morph
status: active
created: 2026-10-06
area: [db, lib, admin, assets]
issue: "#637"
tags: [admin, live, sse, eventsource, postgres, listen, notify, triggers, puma, threads, hijack, cloudflare, tunnel, idiomorph, javascript]
---

# ADR 0118: Keep admin pages live through Postgres notify, a hijacked event stream and a morph

![Active][status]

## Context

Spec #636 keeps every open admin page current without a reload. The owner wants it instant, wants the page's own
content to change and not just the badges, and picked `EventSource` and idiomorph over Turbo, htmx and Alpine. Phlex
stays the only renderer, and every write stays a plain form POST, as [ADR 0055][0055] requires.

A change can come from anywhere. Sidekiq writes from its own process when it syncs issues, the public slice writes
contact messages and webmentions, and the MCP server and the API write on their own. [ADR 0020][0020] keeps
coordination in Postgres, not Redis.

The web process is one Puma with 5 threads (`Blog::Concurrency`), and its pool holds a connection per thread plus
one ([ADR 0006][0006]). Each photo cache miss already holds a thread ([ADR 0080][0080]). The site sits behind a
Cloudflare Tunnel, and Cloudflare ends a request that sends nothing for 100 seconds. A deploy restarts Puma, and
while it restarts the tunnel answers 502.

Some reads write. A read of Today starts the day's sprint through `Tasks::Repos::SprintRepo#claim` when none exists,
and an insert that loses the race to the midnight job does nothing.

The admin scripts are 22 `setup*` modules that `app.js` runs once. `task_order.js` and `markdown_editor.js` keep a
`WeakSet` of the elements they have set up. `fetching.js` holds `setupFetch`, which waits, aborts a stale request
and runs the newest, and `in_place.js` holds `parse`. The key map reads keys from the markup
when a key is pressed, and moves focus to mark the current row ([ADR 0101][0101]).

## Decision

**Postgres triggers announce every change.** One function, `notify_admin_change()`, calls
`pg_notify('admin_changes', TG_TABLE_NAME)`. Each table the admin draws gets an `AFTER INSERT OR UPDATE OR DELETE`
trigger `FOR EACH ROW` that calls it, and the update trigger fires only `WHEN (OLD.* IS DISTINCT FROM NEW.*)`. A
write that changes nothing sends nothing, so an insert that loses a race wakes no page. Postgres sends a notice only on
commit and folds duplicates within one transaction, so a sync of 50 issues sends one notice per table, after the
rows are there to read. A table written on every public page view, such as `analytics_events`, gets no trigger.
A new table the admin draws gets its trigger in the migration that adds it.

**One hub per web process holds every stream.** A hub in `lib/admin`, which an admin slice provider starts on the
first stream, keeps one Postgres connection outside the Sequel pool in `LISTEN admin_changes`. It writes each
notice as an SSE event, named `change` with the table as its data, to every open stream. It writes a comment line
every 30 seconds as a heartbeat and drops any socket that cannot take a write without blocking. When its own
connection drops, it reconnects and sends one event, so pages catch up on what they missed. Under Puma's cluster
mode each fork starts its own hub after the fork.

**Streams cost a socket, not a thread.** `GET /admin/events` runs the GitHub sign-in check like every admin action,
then takes the socket through Rack's full hijack, writes the status line and headers itself
(`Content-Type: text/event-stream`, `Cache-Control: no-cache`, no `Content-Length`, no compression) and a
`retry:` line, and hands the socket to the hub. The Puma thread goes back to the pool at once, so open tabs never
hold the threads that serve pages. Events carry only a table name, so a stream that outlives its session gives away
nothing, and the refetch it causes still meets the sign-in check.

**Every event refreshes every open page.** Pages declare no topics. The client ignores the table name, which is
there for logs and for a later record that wants topics.

**`live.js` refetches the page and morphs it with idiomorph.** It opens one `EventSource` per admin tab. On an event
it calls the page's own URL through `setupFetch`, so events within its wait become one request and a new event
aborts a stale one. It parses the answer with `parse` and morphs `<main>`, the context bar and the palette in place
with idiomorph, which aube adds and esbuild bundles. idiomorph keeps the focused element, the caret and unsent text,
and needs no `unsafe-eval`, so the content security policy does not change: `connect-src 'self'` already admits the
stream. The toast sits outside what the morph touches.

- **Dialogs hold the morph.** While any modal `dialog` is open, the palette and the task modal among them, `live.js`
  keeps the newest answer and morphs when the dialog closes.
- **Rows carry ids.** A row in a list that can grow draws an `id` from its record, such as `message-12`, so
  idiomorph matches it by record and the row the key map has focused keeps its focus when a new row lands above.
- **Reconnects catch up.** After every `open` but the first, `live.js` refetches once. When the stream ends for good,
  as it does when the tunnel answers 502 during a deploy, `live.js` opens a new one after a growing wait.
- **Pages left behind let go.** `live.js` closes its stream on `pagehide` and opens it again when the page comes back
  from the back-forward cache. Chrome keeps a stream open after the tab moves on, so without this the seventh page
  visit in a tab waits on the six-connection limit of HTTP/1.1.

**Setup runs again after each morph.** `app.js` runs one `setup` that runs every module on load, and again whenever
an `admin:morphed` event fires on the document. `live.js` dispatches that event after each morph, so it need not
import `app.js`, which imports it. Each module keeps a `WeakSet` of the elements it set up and skips them, as
`task_order.js` does today, and binds a listener on the document once behind a flag of its own. idiomorph keeps the
nodes it matches and their listeners, so only new nodes get set up. #638 brings the other modules into this shape.

With scripts off, nothing opens a stream and every page works as it does today.

## Alternatives

**Redis pub/sub.** Sidekiq already talks to Redis. A publish sits outside the Postgres transaction, so a page can
refetch before the rows commit, or hear of a change that rolled back, and [ADR 0020][0020] keeps coordination out of
Redis.

**Operations and jobs call `pg_notify` themselves.** The code says when it changed something, and no trigger hides
in `structure.sql`. Writers sit in the admin, public, MCP and API slices and in Sidekiq jobs, and one that forgets
the call leaves pages stale with no warning.

**Statement triggers.** One call per statement, not per row. A statement trigger fires even when it changes no row,
so a read of Today that loses the race for its sprint would wake every open page for nothing.

**More Puma threads.** Each open tab would still hold one, and the pool grows with the threads, so the Postgres
budget in [ADR 0006][0006] grows with every tab. No count is safe, since a tab left open never lets go.

**A process of its own for streams.** It frees Puma, but adds a systemd unit, a port and a tunnel route, and the
process would have to read the admin session cookie to sign in.

**A Rack 3 streaming body.** Puma runs the body on the request's thread until it returns, so each stream still
holds a thread.

**Topics.** A page would list the tables it draws and refetch only for those. Pages draw counts from views such as
`review_tasks` and `activities` that read many tables, and a page that misses one goes stale with no warning. The
admin has one user, so the waste is a page render per open tab per change.

**Turbo 8, htmx with SSE, or Alpine with JSON.** The owner turned these down in #636. Turbo takes over links and
forms, htmx swaps server fragments, and JSON needs a second renderer beside Phlex.

**Replace the markup outright.** Setting `innerHTML` loses focus, the caret and unsent text.

**Delegate every listener to the document.** New nodes would need no setup, but drags, editors and observers keep
state per element, and two modules already guard with a `WeakSet`.

## Consequences

Every writer announces its changes, from any process, with no code. A table the admin draws but nobody gave a
trigger goes stale without a sound.

A read that changes a row in a table with a trigger on every request, such as a timestamp of when a page was last
seen, refetches every open copy of that page for as long as it stays open. Such a table stays out of the trigger
set, or the read stops writing.

Each web process opens one more Postgres connection, 7 at the defaults.

The hub writes to sockets outside Rack, so no middleware sees what it sends, Honeybadger included, and the hub has
to report its own errors. rack-test cannot read a hijacked stream, so stream specs run in the browser against Puma.

A Puma restart drops every stream. Each tab reconnects and refetches once.

Every change costs a page render for each open tab, the tab that made the change among them.

The morph sets every attribute back to what the server drew, so state a script holds in markup, such as an open
disclosure, resets unless the module sets it again.

The session cookie is shared across tabs, so a refetch in one tab can read the toast meant for a redirect in
another, and that toast never shows.

In development the browser talks HTTP/1.1 to Puma and allows six connections per host, so a seventh admin tab
waits. In production the browser talks HTTP/2 to Cloudflare and the limit does not apply.

[0006]: 0006-run-the-site-on-a-raspberry-pi-behind-a-cloudflare-tunnel-with-its-data-on-the-nas.md
[0020]: 0020-keep-locks-throttles-and-claims-in-postgres-not-redis.md
[0055]: 0055-make-every-admin-write-a-plain-form-post-that-scripts-only-add-to.md
[0080]: 0080-store-photos-in-an-s3-store-and-serve-them-through-the-site.md
[0101]: 0101-bind-every-admin-key-through-one-key-map-that-reads-keys-from-the-markup.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
