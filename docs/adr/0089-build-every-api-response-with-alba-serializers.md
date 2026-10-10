---
id: "0089"
title: Build every API response with Alba serializers
status: active
created: 2026-10-01
area: [lib, api, mcp]
issue: "#155"
amended: ["#1011", "#927"]
tags: [api, mcp, json, serializers, alba, dependencies, journal, tasks]
---

# ADR 0089: Build every API response with Alba serializers

![Active][status]

## Context

[ADR 0086][0086] puts a JSON API at `/api/v1` beside the MCP server, and has an endpoint and its tool return the
same JSON. Today each MCP tool builds its own hash. `MCP::Tools::JournalEntries.fields` lists a journal entry's
keys, and `MCP::Tools::TaskTool` holds one helper per shape, such as `comment_entry` and `link_entry`. Nothing
outside the tool that wrote a hash knows its shape.

With two doors returning one shape, a hash written inside a tool would have to be written again inside the
endpoint, and the two would drift. Every resource that moves to the API in a later spec meets the same problem.

## Decision

We build every API response with [Alba] serializers.

- `API::Serializer` in the `api` slice includes `Alba::Resource` and holds what every serializer shares. #1011
  folded `Blog::Serializer` from `lib/blog/serializer.rb` into it, since the API was its only subclass.
- Each resource gets its own serializer in `slices/api/serializers`, a subclass of `API::Serializer`: journal
  entries, tasks, task comments and sprints first (#152), the rest as each resource moves.

An MCP tool on the layer the API and MCP share does not build its own hash. It gets its JSON from the same
serializer, through that layer. #927 made this rule bind tool by tool, as [ADR 0088][0088] moves a resource to the
layer: a tool off the layer may keep its hand-built hash until it moves, even when other tools for its resource
are on the layer. #959 moved many of those tools onto the API serializers, which they call themselves, such as
`list_posts`, `list_messages` and `list_projects`.

The first serializers give the keys the MCP tools return today, so moving a tool onto them changes no output.

## Alternatives

**Hand-built hashes, as the MCP tools build them today.** No new gem, and plain Ruby a reader already knows. It
loses because the shape of a resource would live in a private helper of whichever tool wrote it. An endpoint would
copy the helper or reach into the tool, and nothing would hold the two to one shape.

## Consequences

A resource's JSON has one home, and a change to it reaches the API and MCP together.

The app takes on a gem that every endpoint goes through. A change to how Alba names keys, nests associations or
handles `nil` changes every response at once.

A serializer reads only what the record it gets has loaded. A ROM struct never fetches an association by itself,
so a task serializer that lists tags or links needs the repo to load them first.

Until every tool moves, three styles live side by side in `slices/mcp/tools`: tools that hand off to the layer,
tools that call a serializer themselves and tools that build their own hash. A reader has to check which kind a
tool is.

[0086]: 0086-serve-a-json-api-behind-long-lived-tokens-minted-in-the-admin.md
[0088]: 0088-hold-the-layer-the-api-and-mcp-share-in-the-api-slice-and-call-it-in-process.md
[Alba]: https://github.com/okuramasafumi/alba
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
