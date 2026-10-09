---
id: "0130"
title: Keep service credentials encrypted in a services slice and define each service in code
status: active
created: 2026-10-08
area: [admin, config, db, lib, record, social, tasks]
issue: "#791"
amended: ["#831"]
tags: [services, credentials, encryption, settings, providers, clients, oauth, github, linear, mastodon, bluesky]
---

# ADR 0130: Keep service credentials encrypted in a services slice and define each service in code

![Active][status]

## Context

Every outside service reads its credentials from settings, once, at boot ([ADR 0009][0009]). A second Linear
workspace means editing `.env` on the server and restarting. The admin cannot show which accounts the site holds or
whether they still work, and GitHub takes two credentials for one person: an OAuth app to sign me in and a personal
token for every read. Decision 5 settled that I want to see the services the site talks to, and spec #790 moves
their credentials into the database.

Services sign in four ways. GitHub and Mastodon use OAuth, Mastodon after asking for my server. Bluesky takes a
handle and an app password, and Linear an API key. Honeybadger, MaxMind and the media and backup stores keep their
keys in the environment. Bridgy needs nothing. More services will come, Google first (#708).

## Decision

A new `services` slice owns a `service_connections` table, one row per connected account.

Each service is one definition in code: its name, icon and group, how it signs in (`oauth`, `credentials`, `env` or
`none`), its form fields or OAuth scopes, whether it takes more than one account, and what it powers. The provider
column is text, and the slice checks it against those definitions. #831 lets a service sign in more than one way:
GitHub takes OAuth or a personal access token, and a row made from the form marks that in its credentials.

Each row keeps its credentials in one encrypted column. An encryptor in `lib/blog` holds the key, which comes from
a new `data_key` setting. `Blog::SecretCheck` guards `data_key` with the other secrets, so it cannot repeat
one of them or a committed value.

Clients look up their credentials on each call, not at boot. A provider still registers its client, as ADR 0009
says, but the client asks the slice for the account it needs when it calls out.

OAuth flows stay hand-rolled on the `oauth2` gem, as GitHub sign-in is now.

## Alternatives

**A Postgres enum for the provider**, as [ADR 0015][0015] has us type every closed set. Every new service would then
take a migration, and #790 asks that a service take one definition and no migration.

**OmniAuth.** RFC #779 weighed its Rack strategies for GitHub, Google, Apple and Mastodon, which would save writing
each flow. It adds a dependency with its own session handling, and has no solid Bluesky strategy, so we keep the
`oauth2` flow the app already runs.

## Consequences

A new account works the moment I save it, with no `.env` edit and no restart. A new service is one definition and
the client that uses it.

The database checks nothing about the provider. A row whose provider has lost its definition stays in the table,
and the slice has to skip it rather than fail.

A stolen database or backup holds credentials nobody can read without `data_key`. Losing `data_key` loses every
credential, and I reconnect each account by hand. Rotating it means decrypting and encrypting every row again. With
the key apart from `app_secret`, rotating the session secret signs me out and leaves the credentials alone.

Each call costs a query and a decryption. A spec that changes credentials writes a row, where it stubbed settings and
replaced a registered component before.

Until I connect each service after the deploy, jobs that need it skip, and a social post due in that gap waits.

[0009]: 0009-register-every-service-client-with-or-without-its-credentials.md
[0015]: 0015-type-a-closed-set-as-a-postgres-enum-and-a-format-as-a-domain.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
