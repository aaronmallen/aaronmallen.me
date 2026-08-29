---
id: "0002"
title: Hold app/ and the slices to Hanami's own directories
status: active
created: 2026-09-28
area: [app, assets, lib, activity, admin, analytics, contact, mcp, posts, projects, public, record, social,
  suggestions, tags, tasks]
issue: AA-620
amended: [AA-809]
tags: [layout, hanami, providers, lib, slices, assets]
---

# ADR 0002: Hold `app/` and the slices to Hanami's own directories

![Active][status]

## Context

The codebase was built fast, and almost every part of it reached for one tool: a plain class that takes its
dependencies by hand. `app/` and the slices grew directories Hanami knows nothing about, such as `app/analytics`,
`app/webmentions` and `slices/admin/github`, and they held unlike things side by side: pure functions, wrappers
around an outside service that each read `settings` and built a connection on every call, and one-job classes that
were operations under another name. The directory a file sat in told a reader nothing about what the file was.

`lib/blog` had the same trouble from the other side. It was the only door anyone opened for code with no home, and
it grew to 83 files, four of them used by one slice alone (AA-421).

## Decision

Every slice root holds only Hanami's directories, `actions`, `config`, `contracts`, `db`, `jobs`, `operations`,
`queries`, `relations`, `repos`, `structs` and `ui`, plus the base classes beside them. A slice uses the ones it
needs.

A slice may also keep the entry surface its own protocol forces, beside its actions. Two qualify:

- `slices/mcp/tools`, `slices/mcp/prompts` and `slices/mcp/protocol`. The MCP SDK takes tool and prompt classes and
  derives each wire name from the class name, so `MCP::Tools::SuggestEdits` answers to `suggest_edits`. Moving or
  renaming a class renames a tool.
- `slices/admin/auth`. Its classes read and write the Rack session, so they answer to Rack, not to Hanami.

Everything else goes by what it is:

- Anything whose interface is a client becomes a configurable provider.
- Anything stateless with no configuration becomes plain library code.
- Anything that takes dependencies and does one job becomes an operation.
- A value with rules becomes a type in `Blog::Types`.

### Which `lib` a file goes in

Code lives with what owns it (AA-421, AA-563).

- **`lib/<slice>/`** holds what one slice owns, under that slice's namespace: `lib/admin/search_query.rb` holds
  `Admin::SearchQuery`. The slice loads it with one line in its own `config/slice.rb`,
  `autoloader.push_dir(Hanami.app.root.join("lib/admin"), namespace: Admin)`, which loads the code without
  registering it in the slice's container. A provider moves into the slice that owns its concept, and its key
  crosses by export and import.
- **An export** carries what another slice reaches on purpose: a query for a read, an operation for a write.
- **`lib/blog`** keeps only what no slice owns: the base classes every slice inherits, the shared providers,
  helpers such as `Blog::Truncation` that several slices name, and the shared Phlex kit. The record AA-672 files
  says when a component moves into the kit.

Who names a constant decides who owns it. One slice naming it owns it. Two slices, a feature beside a presentation
slice, give it to the feature. Two of a kind, three slices or more, or a file in `lib/blog` naming it, and no slice
owns it, so it stays in the kernel.

### What `app/` keeps

`app/` keeps `assets` and nothing else. One stylesheet and one shared script, `app.js`, load on every page
(`lib/blog/ui/layouts/application.rb`). Each script belongs to a slice (AA-367): the admin layout adds
`admin/app.js` and the public layout adds `public/app.js`. The MCP pages load only the shared script.

## Alternatives

**Leave the shape alone and group by feature.** The names read well. But a directory named for a feature says
nothing about what its files are, so every new client repeats the settings read, the connection build and the
`configured?` check.

**Apply the rule with no exceptions**, pushing the MCP tools into `actions/` and the session into `structs/`. One
rule, nothing to remember. It loses because the SDK derives each tool's wire name from its class name, so the move
would rename the tools Claude calls, and because the session is Rack's, not ours.

**Keep a constant in `lib/blog` whenever a component reaches it from outside its slice.** The first version of this
record held that a Phlex component takes no `Deps`, so it reaches a constant or nothing, and it may not name
another slice's constant. That rule, with the app sharing clients through `shared_app_component_keys`, dragged
social's clients and GitHub's client into the `Blog` namespace and pinned `Blog::Markdown` in the kernel (AA-563).
It lost to ownership: a component may name a constant of the slice that owns it.

**`slices/<name>/lib`**, which Hanami adds as a component directory of its own and registers every class in.
The code in `lib/<slice>` is plain library code that callers reach by constant, so each file there would need an
`# auto_register: false` comment to stay out of the container, the way `slices/admin/auth/session.rb` carries one
today. A repo-root `lib/<slice>` keeps that code out with no comment on any file.

## Consequences

Where a file sits says what it is, and each kind has one home.

Every move renames a container key, so each `Deps[...]` string that names the moved class changes with it. Nothing
checks those strings until the code runs.

Each slice that owns library code pays one `push_dir` line in its `config/slice.rb`, and its code sits one
directory away from the slice, under `lib/` rather than inside `slices/<name>`.

The rule has exceptions: `auth` in admin and `prompts`, `protocol` and `tools` in mcp. This record says why.

No spec checks the layout or who owns a kernel constant. A kernel constant that drops to one slice naming it stays
in `lib/blog` until someone moves it to `lib/<slice>/`.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
