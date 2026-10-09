---
id: "0009"
title: Register every service client, with or without its credentials
status: active
created: 2026-09-28
area: [admin, analytics, config, lib, projects, record, social]
issue: AA-674
amended: [AA-822, "#791"]
tags: [providers, clients, settings, credentials, github, maxmind, bluesky, mastodon]
---

# ADR 0009: Register every service client, with or without its credentials

![Active][status]

## Context

Five clients talk to outside services: the GitHub API, GitHub sign-in, the MaxMind GeoLite2 download, Bluesky and
Mastodon. Each needs credentials the site may not have. A fresh checkout, the test suite and a site that never
posts to Mastodon all run without some of them, so `config/settings.rb` makes every one optional: the `github`,
`maxmind`, `bluesky` and `mastodon` settings default to `{}`, and a blank value reads as `nil`.

The admin still has to know which clients it can use. The sign-in page answers 503 when GitHub sign-in has no
app, the social post form offers only the networks that can post, and the Today dashboard says whether GitHub is
connected.

The former ADR 0002 turned each client into a provider and left one question open: whether a provider registers a
client that still answers `configured?`, or a null client the admin asks about another way. The code settled it.

## Decision

A provider always registers its client. With no credentials it builds the client on a `nil` connection, and the
client answers `configured?` false and returns `nil` from every call.

- `Record::Providers::GitHubProvider` builds the transport on `nil` when `api_token` is missing.
- `Admin::Providers::GitHubAuthProvider` hands `Admin::Auth::GitHub` no OAuth2 client unless both `client_id` and
  `client_secret` are set.
- `Analytics::Providers::GeoProvider` builds the GeoLite2 client on `nil` unless both MaxMind values are set.
- `Social::Providers::NetworksProvider` builds Mastodon on `nil` when the URL or the token is missing, or the URL
  will not parse. Bluesky builds its connections either way and answers `configured?` from its handle and
  password.

A caller asks `configured?` before it calls out. An operation answers `Failure(:not_configured)`, as
`Record::Operations::ImportCommits` and `Analytics::Operations::RefreshCountryDatabase` do. An action or a view
shows the state, as `Admin::Actions::Sessions::New` does.

Since #791 the GitHub, Linear, Mastodon and Bluesky credentials live in the database, not in settings, and a client
looks them up on each call rather than at boot ([ADR 0130][0130]). Their providers still register a client either
way.

## Alternatives

**Required settings.** A setting whose constructor has no default, as `analytics_salt` has, stops the app at boot
when the value is missing, so a missing credential shows up at once. It lost because the site has to run with no
GitHub token, MaxMind key or social credentials.

**A null client**, registered in place of the real one when credentials are missing. It keeps the `nil` checks out
of the real clients. But the admin shows which clients are set up, so it would have to ask about a null client
some other way, which the former ADR 0002 named and left open. No issue records it being weighed further.

## Consequences

The site boots with any set of credentials. Adding one turns its feature on at the next boot, with no other change.

A missing credential shows up only when a job or a screen asks. The GitHub jobs record `:not_configured` as a
sync failure, which the admin shows as "No GitHub token is set". `Analytics::Jobs::RefreshCountryDatabase` counts
it as a success, so a MaxMind key left out of the environment looks the same as a night the refresh worked.

Every client checks for `nil` in each method that calls out, and fourteen call sites in `slices` ask `configured?`
first. A new client and its callers take the same shape.

A provider reads its settings once, at boot, so stubbing the settings in a spec changes nothing. A spec that
changes credentials has to start the provider, stub the settings and replace the registered component, as
`spec/support/github_credentials.rb` does for GitHub and `spec/support/social_credentials.rb` for the networks.

[0130]: 0130-keep-service-credentials-encrypted-in-a-services-slice-and-define-each-service-in-code.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
