---
id: "0179"
title: Fetch every outside page through one guarded app-level client
status: active
created: 2026-10-15
area: [config, lib, posts, shares, social]
issue: "#1455"
tags: [http, fetch, security, webmentions, short-links, providers, clients]
---

# ADR 0179: Fetch every outside page through one guarded app-level client

![Active][status]

## Context

`Social::Webmentions::Client` in `lib/social/webmentions` fetches pages at URLs the site did not write. It resolves
the host and refuses it unless every address passes `Blog::PublicAddress`, pins the connection to the address it
checked, takes ports 80 and 443 only, follows at most three redirects and checks each hop the same way, and stops at
15 seconds or 1 MB. The `social` slice registers it twice, as `webmentions.client` and `webmentions.link_checker`,
and `posts` reaches the second through `social`'s `operations.check_link`.

The webmention trust rules lean on it. [ADR 0107][0107], which replaced [ADR 0042][0042], checks the author scope
against the URL the fetch landed on, so the redirects it follows are the redirects trust sees.

Spec #1454 has the `shares` slice fetch a short link's destination for its title. That URL is one I chose, but a
redirect can still send the fetch anywhere. `social` imports from `shares`, so `shares` cannot import the client back
without a cycle ([ADR 0003][0003]). The app-level `http` provider builds plain Faraday connections with none of the
checks above.

## Decision

Every fetch of a page at a URL the code does not hold as a constant goes through one guarded page fetcher. No slice
fetches such a page through `http` or a Faraday connection of its own.

- **The fetcher moves to its own folder under `lib/`**, out of `lib/social`, as [ADR 0159][0159] lays out for a job
  more than one slice does. The folder holds the client, its errors and its provider builder.
- **It registers in `config/providers`**, and a slice takes it through `shared_app_component_keys`. Each caller may
  set its own user agent; the checks and limits stay the same for all of them.
- **`social` uses it** for webmention sending, verifying and link checks, and `posts` keeps reaching link checks
  through `social`. **`shares` uses it** to fetch short link titles.

`http` stays for service APIs at hosts the code names, such as GitHub and Linear.

## Alternatives

**Import the client from `social` into `shares`.** `social` already imports `shares`, so the two would import each
other.

**Fetch titles through `http` in `shares`.** A second fetcher would have to copy the address checks, the pinned DNS
and the limits, or go without them and let a redirect reach the home network.

## Consequences

A slice that fetches a page has one client to find, and a fix to the guards reaches every caller at once.

A change to the limits reaches every caller too. A title fetch needs only a page's `<head>` but waits up to 15
seconds and reads up to 1 MB, as a webmention source does.

Nothing enforces the rule. `http` stays app-level, so a slice can still build a connection around the fetcher, and
only review catches it.

The fetcher's errors and response move with it, so the webmention operations, the development seeds and their specs
rename what they rescue and stub.

[0003]: 0003-reach-another-slice-only-through-its-exports.md
[0042]: 0042-trust-a-webmention-author-by-exact-url-on-their-own-host.md
[0107]: 0107-trust-a-webmention-author-only-under-their-url-and-a-whole-host-only-when-marked.md
[0159]: 0159-group-shared-lib-code-by-service-and-register-service-clients-at-app-level.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
