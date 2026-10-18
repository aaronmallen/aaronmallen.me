---
id: "0158"
title: Match the owner on a verified email from GitHub or Google
status: active
created: 2026-10-12
area: [admin, config, db, lib, security]
supersedes: ["0131"]
issue: "#1155"
tags: [auth, oauth, github, google, owner, identities, sign-in, email, sessions]
---

# ADR 0158: Match the owner on a verified email from GitHub or Google

![Active][status]

## Context

ADR 0131 kept the owner as rows in `owner_identities`, each a provider and that provider's id for the account. Only
GitHub could sign in, matched on its numeric user id, and the sign-in asked for no scopes. When GitHub is down or
the account is locked, nobody gets into the admin.

The Google OAuth client the data slices use (ADR 0149) can also prove who the owner is. GitHub and Google share no
id, so a row keyed on one provider's id cannot let the other in.

## Decision

The admin signs the owner in with GitHub or Google, and both match the same thing: an email the provider has
verified.

- `owner_identities` is a list of emails with no provider column. Any row lets in either provider. The owner adds
  rows by hand, as ADR 0131 said, and the dev seed adds one.
- `GET /admin/sign-in` renders a page with a button for each provider. Each button posts to
  `/admin/sign-in/:provider`, which answers 503 when that provider's credentials are not set (ADR 0009).
- Every provider has one callback for signing in and connecting alike. The `site.auth_callback_path` setting names it,
  from `AUTH_CALLBACK_PATH`, and defaults to `/admin/auth/:provider/callback`. A state the
  connected services tab started connects an account, and any other state signs in.
- GitHub sign-in asks for `user:email` and takes the address `GET /user/emails` marks primary and verified.
- Google sign-in asks for `openid email`, takes the userinfo email only when `email_verified` is true, and writes no
  `service_connections` row. `Admin::Auth::Google` builds on the same OAuth client as `Google::Client`.
- Neither provider's token outlives the callback.
- The session cookie holds the email in place of `github_user_id`, and `signed_in?` checks it against the table on
  every request.
- `sign_ins` names the provider each sign-in went through, and its failed outcome is `provider_failed` for both.

We give up the reason ADR 0023 picked the GitHub id: a login can change hands, the id cannot. A verified email can
change hands too, but only with the inbox, and losing the inbox already loses every account that resets through it.
The id never let a second provider in, and the email does.

## Alternatives

**A row per provider, keyed on Google's `sub` beside the GitHub id.** It keeps ADR 0131's shape, but the owner adds
and keeps one row per provider, and a third provider adds a third.

**Leave GitHub on its id and match only Google on email.** Two kinds of row and two checks, and GitHub still needs
its own row.

## Consequences

One row lets the owner in through either provider, and a third provider that verifies email needs no new row.

Whoever controls an email in the table, and gets it verified at GitHub or Google, owns the site. The table is only as
safe as those inboxes.

GitHub sign-in no longer asks for no scopes. Its token reads the account's private email list, so a leaked one gives
that away, though nothing keeps it.

The migration drops the GitHub id rows. The live site needs an email row before deploy, and every session ends,
since old cookies hold no email.

The Google OAuth client takes a second redirect URI, and the owner adds it in the Google console.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
