---
id: "0007"
title: Read settings from the environment's file, then default.yml, then the environment
status: active
created: 2026-09-28
area: [config]
issue: AA-353
amended: [AA-797]
tags: [settings, environment, yaml, erb, secrets, fork, hanami-settings-stores]
---

# ADR 0007: Read settings from the environment's file, then default.yml, then the environment

![Active][status]

## Context

Hanami reads each setting from the environment variable of the same name, and loads `.env` only when the `dotenv`
gem is bundled. The site put a `Hanami::Settings::CompositeStore` in front of that from its first commit, but
`config/settings/default.yml` was twenty `ENV` lookups, so the files held almost nothing of their own. Sixteen
lookups had no default, so each was `nil` unless somebody knew the variable's name, and nothing listed the names.
Public facts about the site, such as the Bluesky handle and the Mastodon instance, sat beside the secrets as though
they were secrets too. Values that should differ by environment, such as `site.url`, did not (AA-353).

AA-353 drew the line: secrets live in the environment, and everything else lives in a settings file. It also met
the catch any order brings. When a file and a variable both hold a key, one of them wins. AA-325 had pinned an
`app_secret` in `development.yml`, so the `APP_SECRET` in `.env` stopped counting in development. AA-353 called
that right for a value fixed per environment and wrong for one a person needs to change without editing the
repository, and asked that each setting pick one.

AA-354 then moved every personal fact out of the Ruby, so that a fork edits settings and no code.

## Decision

`config/app.rb` replaces Hanami's store with a `Hanami::Settings::CompositeStore` from `hanami-settings-stores`. It
asks three stores in turn, and the first to hold a top level key wins:

1. `config/settings/<env>.yml`, for what differs by environment: the database, Redis, `site.url`, and the pinned
  development and test secrets.
2. `config/settings/default.yml`, for what is the same everywhere: the owner, the profile links and the social
  handles.
3. The environment, for a top level key neither file holds. Production reads `APP_SECRET` and `ANALYTICS_SALT`
  this way.

A key inside a file opts into the environment through ERB, one line per variable, as every key under `github` but
`profile_url` does. Every hash is plain YAML, so a variable nobody set leaves its key holding `nil`. The type in
`config/settings.rb` takes that `nil` as unset: `Value` keeps it, and a throttle falls back to its default. AA-797
added this rule.

A fork changes `default.yml`, or sets `OWNER_GITHUB_ID` to change only whose GitHub account signs in. A deploy sets
only variables: the secrets, where Postgres and Redis answer, and `PROXY_TRUSTED_PROXIES`. `.env.example` lists
them all.

## Alternatives

**The environment alone, Hanami's default, with `.env` read by `dotenv`.** A `default.yml` of nothing but `ENV`
lookups worked the same way, and AA-353 took it apart: the names live nowhere a reader can find them, a public fact
reads as a secret, and every environment gets the same value unless somebody sets a variable.

**The environment first, then the files**, the order the gem's own example uses. Any variable of the right name
would then beat a file, so the `APP_SECRET` that `mise run setup:environment` writes to `.env` would replace the
one `test.yml` pins. AA-353 wanted each setting to choose, and the file first lets it: a literal is fixed for its
environment, and an ERB line hands the key to the environment.

**A hash built in ERB and written out with `.compact.to_json`**, the rule until AA-797. `.compact` dropped a
missing variable, so its key never reached the type and the default applied. It worked, but four settings in
`default.yml` then read as one long line of Ruby holding a JSON string, unlike every hash around them, and the
default hung on a key being absent rather than on the type.

## Consequences

A setting's home is plain. A secret goes in `.env.example`, with an ERB line when it sits inside a hash. A fact
goes in `default.yml`, and a value that differs by environment in each environment's file.

The first hit wins and nothing merges. A top level key in `development.yml` hides the whole hash of that name in
`default.yml`, so each environment file repeats every `database` key it needs.

The environment reaches a nested key only through its ERB line. Add a key to `github` with no such line and no
variable can set it, and nothing says so.

The app gets no `.env` of its own. mise loads it for every task, so `bundle exec hanami console` from a plain shell
sees no secrets.

`FileStore` raises when its file is missing, so the app boots only as `development`, `test` or `production`.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
