---
id: "0026"
title: Coerce a param in the action, validate it in a contract
status: active
created: 2026-09-28
area: [lib, activity, admin, analytics, contact, mcp, posts, projects, public, record, social, suggestions, tags, tasks]
issue: AA-462
amended: [AA-542, AA-543, AA-809]
tags: [actions, params, coercion, validation, types, contracts]
---

# ADR 0026: Coerce a param in the action, validate it in a contract

![Active][status]

## Context

A Hanami action takes a `params do` schema, or a `contract do` block through dry-validation, and the Hanami guides
teach `params do` as the way to allowlist and coerce. After either, `request.params[:x]` comes back coerced and
the action can ask `request.params.valid?` and read `request.params.errors`.

Below the action a `Blog::Contract` owns validation. AA-453 moved the predicates into the schema and gave them
messages in `config/errors.yml`, which `lib/blog/contract.rb` loads. AA-454 made the contract the only place a
form value is coerced. An operation runs the contract, `Blog::Operation#validated` turns a failure into
`Failure([:invalid, errors])`, and the view renders the errors beside the fields.

The layer above was never decided, so five places each answered it alone: `Date.iso8601` behind a
`rescue Date::Error` for the activity range, `FILTERS.include?(status) ? status : ALL` for the posts filter,
`request.params[:code].is_a?(String)` on the GitHub callback, a `filter_map` over permitted keys for the
webmention settings, and `decision == APPROVE ? decision : CANCEL` on the OAuth consent form. Five params, five
dialects, and a sixth waiting for whoever writes the next action.

## Decision

**An action never validates. It coerces, and only through `Blog::Types`.**

Coercing turns what arrived into a value the code below can use, and it always lands on one. A param that must
have a value gets a fallback type, named `*Param` and published from `lib/blog/types.rb` beside its enum, such as
`TaskTabParam`, `PostFilterParam`, `OAuthDecisionParam` and `DateParam`. Free text goes through `Text` and a
nested form through `Fields`.

Validating decides whether what arrived is acceptable and says why when it is not. That belongs to a
`Blog::Contract` an operation runs, and it reaches the action as `Failure([:invalid, errors])`. An action that
wants to refuse a request refuses on that failure, not on a check of its own.

The rule holds wherever a raw param is first read, so an operation an action hands a raw param to reads it the
same way. `Admin::Operations::BuildPostsPage` and `BuildActivityPage` take the filter and the dates through
`PostFilterParam` and `DateParam`.

## Alternatives

**Take Hanami's `params do` schema in the action.** It is the framework's answer and it would end the five
dialects too. It lost on three counts. It puts a second schema over a request the contract below already coerces,
which is the doubling AA-454 removed. The schema cannot reach `Blog::Contract`, so it would not load
`config/errors.yml` and its messages would be dry-schema's defaults. And `request.params.errors` has a different
shape from the `Failure([:invalid, errors])` every view renders, so the two would meet in the same templates.

**Take `contract do` in the action.** Closer, since it is dry-validation either way, but the block builds an
unnamed contract inside the action class. It cannot inherit `Blog::Contract`, and no spec can exercise it apart
from a request. Handing `contract` a class we already have does not help either:
`Analytics::Contracts::VisitContract` and `MCP::Contracts::ClientRegistrationContract` are `json` contracts bound
to a parsed body, not to form params, and the `params` contracts in `slices/mcp/contracts` already run inside
the operations `Authorize` and `IssueToken`.

**Leave each site to answer for itself.** What we had. It reads as five unrelated tricks, and every one of them
hides a decision about what a missing or wrong value means.

## Consequences

An enum-shaped param costs two lines in `Blog::Types` before an action can read it, and `Blog::Types` keeps
growing. The payment is that the values live once and a wrong one raises at the enum.

A fallback never refuses. A bad `?status=nonsense` shows every post rather than a 404, which is what we want for a
filter in a query string and not what we would want for an id. An action that must refuse has an operation refuse
for it.

An action stays thin enough to read in one screen, and a reader who wants to know what a request may contain
opens the contract. The cost is that the action no longer says. Hanami's own answer sits unused.

No spec checks the rule. A `params do` block, a test or parser over a raw param, or `to_i` on one passes the suite,
so the rule holds by habit and review. The GitHub callback already breaks it: it asks
`request.params[:error].nil?`.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
