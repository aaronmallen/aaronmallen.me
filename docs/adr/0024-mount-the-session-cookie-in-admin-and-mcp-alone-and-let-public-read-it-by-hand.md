---
id: "0024"
title: Mount the session cookie in admin and mcp alone, and let public read it by hand
status: active
created: 2026-09-28
area: [config, lib, admin, mcp, public]
issue: AA-664
amended: [AA-809]
tags: [sessions, cookies, csrf, privacy, auth, hanami]
---

# ADR 0024: Mount the session cookie in admin and mcp alone, and let public read it by hand

![Active][status]

## Context

Two slices need a session. The admin keeps the operator's sign-in in one, and the MCP consent screen needs the same
sign-in, a `return_to` and a CSRF token.

The public site promises no cookie. The records on the daily visitor hash and the contact form rest on it: no
consent banner, no analytics cookie, no third-party script. Rack's cookie store writes back any session a request
loads, and Hanami's CSRF protection, which turns on with sessions, writes a token into the session on every
action, so a session on the public slice sets a cookie on every public page.

The public site still has to know when the operator is looking. It draws the admin items in the settings menu, it
skips counting the operator's own visits, and it keeps caches from storing the operator's copy of a page.

Two framework facts shape how a slice gets a session:

- `config/routes.rb` mounts each slice with a blockless `slice :name, at:`. That inlines the slice's routes into the
  app's router (`hanami-3.0.2/lib/hanami/slice/router.rb`), so the slice's own router, which would mount its
  session middleware, never builds. The `use` line in the slice's routes file is the only mount.
- The app sets no session, so Hanami settles the app's `csrf_protection` to false
  (`hanami-3.0.2/lib/hanami/config/actions.rb`) before any slice copies the config. A slice with a session sets
  `csrf_protection` itself.

## Decision

The app sets no session. Admin and mcp each set `config.actions.sessions = Blog::SessionCookie.store`, one cookie
named `admin.session`, and mount it from their routes with `use(*Slice.config.actions.sessions.middleware)`. Admin
mounts it over every route and sets `csrf_protection = true`. Mcp mounts it only in its `/oauth` scope, sets
`csrf_protection = false`, and includes `Hanami::Action::CSRFProtection` in `MCP::BrowserAction` alone, so the
consent screen checks the token and the JSON endpoints never ask for one.

Public mounts no session. It reads the cookie through `admin.auth.session_reader`, which admin exports and public
imports. `Admin::Auth::SessionReader` takes the session Rack loaded when one ran, and otherwise decrypts the cookie
itself from admin's session options, trying each secret. Reading writes nothing back. `Public::Slice` sends
`Vary: Cookie` on every response, and `Public::Action` sends `private, no-store` when the operator is signed in.

The consent screen borrows the admin's sign-in. `MCP::BrowserAction` reads the session through the same export, sends
a signed-out operator to the admin's sign-in with `return_to` set, and checks the CSRF token the shared cookie
carries.

## Alternatives

**One `config.actions.sessions` on the app**, the shape the Hanami guide gives. Every slice would share the session
and the CSRF token with no hand-written reader. It lost because every public page would then set a cookie, which the
no-cookie rule forbids.

## Consequences

The public site sets no cookie, and `spec/slices/public/requests/pages_spec.rb` checks the five main pages for a
`set-cookie` header.

`SessionReader` copies what the middleware does. It reads the key, `serialize_json` and `secrets` from the
admin's session options, which `Blog::SessionCookie.store` sets, but it builds `Rack::Session::Encryptor` itself.
A change to the store that Rack's middleware reads and the reader does not, such as a new coder, leaves every
public page treating the operator as a stranger. Only the request specs that sign in and then load a public
page, such as `spec/requests/cache_headers_spec.rb`, would notice.

Every public response varies on `Cookie`, so a shared cache has to key each copy on the whole cookie header a
visitor sends.

A new slice that needs the operator repeats the pattern: set the store, mount it in the routes file, set
`csrf_protection`, or read the cookie through the export.

The consent screen ties mcp to admin. Admin imports the client queries from mcp, and mcp imports the session reader
from admin, the one import cycle ADR 0003 allows (AA-448).

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
