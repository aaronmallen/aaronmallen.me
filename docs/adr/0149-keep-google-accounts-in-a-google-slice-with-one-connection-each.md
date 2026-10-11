---
id: "0149"
title: Keep Google accounts in a google slice with one connection each
status: active
created: 2026-10-11
area: [admin, config, db, health, lib, services]
issue: "#1121"
tags: [google, gmail, calendar, health, slices, services, oauth, scopes, accounts]
---

# ADR 0149: Keep Google accounts in a google slice with one connection each

![Active][status]

## Context

[ADR 0146][0146] put the Google client in the `health` slice as `Health::Google::Client`. It reads the Health API
only, holds one `google_health` connection and takes the first row it finds. [ADR 0130][0130] named Google as the
next service with more than one account.

Spec #1119 brings Gmail and Google Calendar into the admin. My mail lives in three Google accounts, and a new `mail`
slice and a new `calendar` slice both need to read and write through Google. Only the main account should grant
Health.

## Decision

A new `google` slice owns the Google client, which moves to `lib/google`. The client takes the API base URL per call,
so Health, Gmail and Calendar share one OAuth flow and one token refresh. `health`, `mail` and `calendar` import it
from the `google` slice ([ADR 0003][0003]).

One `google` service definition replaces `google_health` and takes more than one account. Each account is its own
row in `service_connections`, with the scopes it granted. The Health scopes go to the main account only, and the
health sync reads from that account. An account that lacks a scope shows Grant, which reconnects it with the scope.

A new migration moves the `google_health` row to `google`, so the account Health syncs on carries over without a
reconnect.

## Alternatives

**Widen the client in place inside `health`.** Adding scopes and a connection per account there would work, but
`mail` and `calendar` would then import a Gmail and Calendar client from the slice that owns sleep and workouts,
and `health` would own scopes it never uses.

## Consequences

A new Google account works the moment I connect it, and a new Google API is a base URL and the scopes it needs.

Every call has to name the account it acts for. A call that picks the first row, as the Health client did, reads
whichever account came first.

The provider, settings key and OAuth callback route change name from `google_health` to `google`, so the redirect
URI in the Google OAuth app changes with them, and Health sync stops until it matches.

Gmail scopes are restricted. Until Google verifies the OAuth app, an app in Testing loses its refresh tokens every
7 days, and a Workspace account may refuse it.

Disconnecting one account revokes its token and leaves the others alone.

[0003]: 0003-reach-another-slice-only-through-its-exports.md
[0130]: 0130-keep-service-credentials-encrypted-in-a-services-slice-and-define-each-service-in-code.md
[0146]: 0146-keep-health-data-in-a-health-slice-as-daily-summaries-and-workouts-polled-from-google.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
