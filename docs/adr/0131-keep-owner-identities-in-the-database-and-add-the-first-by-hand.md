---
id: "0131"
title: Keep owner identities in the database and add the first by hand
status: active
created: 2026-10-08
area: [admin, config, db]
supersedes: ["0023"]
issue: "#792"
tags: [auth, oauth, github, owner, identities, sign-in, settings]
---

# ADR 0131: Keep owner identities in the database and add the first by hand

![Active][status]

## Context

ADR 0023 let one GitHub account into the admin: the one `owner.github_id` names. `Blog::Settings#operator?` compares
it to the signed-in id, and `Admin::Auth::Session#signed_in?` runs that check on every request. One id in settings
leaves no room for a second way to prove who the owner is, such as Google or Mastodon.

The spec in #790 moves every outside service into connected accounts kept in the database. GitHub had served two jobs
under one setup: signing the owner in and reading data with a personal token. That spec splits them, so sign-in now
only has to prove who the owner is.

## Decision

The owner is a set of identities in a table that `admin` owns, since it owns sign-in. Each row names a provider and
the provider's id for the account. For GitHub that is the numeric user id, for the reason ADR 0023 gave: a login can
change hands, the id cannot.

- The owner adds the first identity by hand, straight into the table. Nothing in the app adds one.
- Sign-in lets in a GitHub account only when the table holds it. Any other account is turned away before a session
  exists, as before.
- With an empty table, nobody can sign in.
- Sign-in stays with GitHub OAuth and asks for no scopes. Reading GitHub data is a connection on the connected
  services tab, like every other service.
- `owner.github_id` and `OWNER_GITHUB_ID` go. `owner.name` stays.

Everything else ADR 0023 decided holds: the encrypted cookie, the 30 day session, and sign-out ending every session.

## Alternatives

**Keep the setting.** Nothing to build, but one GitHub id is the only proof of ownership there can be, so no other
provider has anywhere to go.

**Seed the table from the setting at boot.** The table exists, but `OWNER_GITHUB_ID` has to stay in the environment
for good, and the setting and the table can disagree.

**Let the first sign-in claim the site.** Nothing to add by hand, but whoever signs in first after a deploy or a fresh
database owns the site. The owner has to get there before anyone else, and nothing makes sure of that.

## Consequences

Adding a provider means adding a row and a sign-in route, not a setting.

A fresh database, in any environment, locks everyone out until someone adds a row. Dev seeds add an identity so that
local work does not hit this. The owner adds a row on the live database after the first deploy, before signing in.

Ownership now lives in the data, so it travels with backups and a restore brings it back. Anyone who can write to the
table can make themselves the owner.

`signed_in?` reads the table on every request, beside the `session_validity` row it already reads.

A sign-in that asks for no scopes gets a token that reads only public profile data, so leaking it gives nothing away.

The MCP consent screen (ADR 0056) builds on this sign-in, so it inherits these costs too.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
