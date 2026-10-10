---
id: "0001"
title: Split the app into slices by feature
status: active
created: 2026-09-28
area: [app, config, lib, activity, admin, analytics, api, backups, contact, decisions, links, mcp, media, posts,
  projects, public, record, saved_views, search, security, services, social, suggestions, tags, tasks]
issue: AA-587
amended: [AA-422, AA-525, AA-563, AA-570, AA-809, "#137", "#274", "#302", "#316", "#319", "#950", "#951", "#957"]
tags: [slices, layout, hanami, exports, providers, clients, assets]
---

# ADR 0001: Split the app into slices by feature

![Active][status]

## Context

The site started as a Hanami app with no slices. The admin spec (AA-203) added a private admin at `/admin` that one
person signs in to, and the MCP server (AA-212) came with it.

Some of that has to stay private. Journal entries (AA-206) are mine to read, and commit records (AA-234) cover
private and org repos, so neither may reach a public page. Posts both sides read.

We split by audience first: `slices/admin`, `slices/mcp`, and the public site left in `app/` beside every record
both sides read. By AA-363, `app/` held eleven actions, fifteen relations, eight repos, fifteen operations and
twenty-eight components, and admin reached back into it through a list of fourteen shared keys. Adding a field to a
post meant editing `app/`, `slices/admin` and `slices/mcp`. Journal entries sat in `slices/admin` because only the
admin read them, so AA-324 had to write a spec proving one cannot reach a public tag page. Privacy rested on where a
file sat.

The first split by feature kept one habit from the old shape: the app built every outside client and shared it.
AA-508 found that two of those clients had one reader each. An app provider cannot name a constant from a slice's
`lib`, so every client class sat in `lib/blog` under the `Blog` name while one slice owned it (AA-565).

## Decision

We split the code by what it is about, not by who reads it. Twenty-two slices, of two kinds, since #274 added
`decisions`, #302 added `search`, #316 added `saved_views`, #319 added `links`, and `backups`, `security` and
`services` came after (#957).

**Four presentation slices** own routes, actions, layouts and views: `public`, `admin`, `api` and `mcp`.
`config/routes.rb` mounts these four and nothing else. A presentation slice owns no feature's records, only the rows
its own door needs: `admin` owns `session_validity` and `owner_identities` (#957), `api` owns `api_tokens`, and
`mcp` owns `oauth_clients`, `oauth_codes` and `oauth_tokens`. Any other needs its own record.

**Eighteen feature slices** own relations, repos, structs, contracts, operations and jobs, and answer no route:
`activity`, `analytics`, `backups`, `contact`, `decisions`, `links`, `media`, `posts`, `projects`, `record`,
`saved_views`, `search`, `security`, `services`, `social`, `suggestions`, `tags` and `tasks` (#957). Each owns its
tables outright, and a slice reaches another only through its exports.

Privacy rides on those exports, not on where a file sits. `record` exports its journal and commit reads to `admin`,
`activity` exports its feed to `admin` and `mcp`, and `public` imports from neither.

**Each client is a provider in the slice that owns it.** `record` registers `github.client` and `linear.client`,
`social` registers `networks.all` and `webmentions.client`, `analytics` registers `geo.countries` and
`geo.geo_lite2.client`, `media` registers `store.client` (#137), `backups` registers `backup_store.client` and
`dumper`, and `admin` registers `github.auth`, `mastodon.auth` and `live.hub` (#957), each under its own
`config/providers`. A slice
that calls another's client imports its key, as `projects` and `admin` import `github.client` from `record`.

**The app shares only what no slice owns, and a slice names each piece it takes** in
`config.shared_app_component_keys`: `assets`, the one compiled bundle, for `public`, `admin` and `mcp`; `http`, the
connection builder under the GitHub, network, webmention and GeoLite2 clients, for `analytics`, `record` and
`social` (AA-747); `honeybadger.agent` for `admin`, `mcp`, `posts` and `social`; and `sidekiq.dead_set` for
`activity` (#951).

Four keys break the rule on purpose, and `config/app.rb` shares them with every slice:
`contracts.contributor_terms_contract`, `contracts.review_range_contract`, `contracts.search_query_contract` and
`operations.read_visitor_address`. They left `lib/blog` in #721, where every slice already reached them, and seven
slices read them now, so no slice owns them. Sharing them once saves seven lists of the same keys (#951).

What `app/` keeps and which `lib` a file goes in are ADR 0002's, since #950. This record first gave `app/` the
asset sources and no Ruby.

## Alternatives

**Split by audience**, where this record started. It puts the sign-in check, the admin routes and the admin layout
in one place and moves the public site nowhere. A feature still grows in three directories, and a record sits where
its readers put it, so a record that gains a public reader has to move.

**Audience plus feature**: `slices/public` and `slices/admin` over a shared domain still in `app/`. It gets the
public site out of `app/` for a third of the work, but `app/` then holds every table in the site, which is the blob
under a shorter name.

**Clients the app builds and shares with every slice**, which this record chose until AA-563. The clients hold no
state, and one named line in `slice.rb` is less than a provider file per slice. It lost because it put a class one
slice owns in `lib/blog`, and because the owning slice can build the client once and export its key, which costs
no second copy of the GeoLite2 database.

## Consequences

Where a record lives no longer depends on who reads it. The spec AA-324 wrote now describes something the container
refuses to do.

A feature grows in one directory, and its dependencies are lines in its `slice.rb` rather than a trace through call
sites. That holds for clients too: a reader of `github.client` shows as an import from `record`.

A client with readers in four slices, as `networks.all` has, adds an import edge to each. An edge that carries only
provider keys does not count toward a cycle, so `posts` can import `networks.all` from `social` while `social`
imports from `posts`.

Twenty-two slices mean twenty-two containers to boot and twenty `db` providers, one for each slice that owns
rows (#957). A new
feature costs a directory tree and a `slice.rb` before it holds a line of code.

`app/` holds the asset sources and the few pieces no slice owns, as ADR 0002 lists them (#950). A reader who opens
it finds little of the code, and has to know that the rest is in `lib` and `slices/`.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
