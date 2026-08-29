# aaronmallen.me

My personal website and blog. Nothing is deployed yet, but the app is built: a public blog (`slices/public`), an
admin behind GitHub sign-in (`slices/admin`), and an MCP server for proofreading drafts (`slices/mcp`).

## Stack

- [Hanami] 3 app, namespaced `Blog` (@config/app.rb, @config/routes.rb). Shared base classes live in `lib/blog`.
- [Phlex] views through `phlex-hanami`. Views are Ruby classes, not templates.
- [dry-operation], dry-types and dry-validation for business logic (`Blog::Operation`, `Blog::Types`).
- Postgres through ROM and Sequel (`lib/blog/db`, `config/db`). The schema lives in @config/db/structure.sql.
- [Sidekiq] and sidekiq-scheduler for background jobs (@config/sidekiq.rb).
- Settings come from `config/settings/<env>.yml`, then `default.yml`, then the environment, through
  `hanami-settings-stores`.
- Tailwind CSS and esbuild for assets (`app/assets`, @config/assets.js). aube manages the node packages.
- RSpec with Capybara, rack-test and rom-factory for tests (`spec`).

## Tooling

- [mise] manages tools and tasks (@.config/mise.toml). Run `mise tasks` to see them.

Always run the work through a mise task rather than calling `rspec`, `rubocop`, `markdownlint-cli2` or **any** other
tool yourself. The tasks in `scripts/` carry the flags, config paths and database checks this project depends on, and
they are what I run, so a bare `rubocop` reads no config at all.

- `mise run format` and `mise run lint` cover every language.
- `mise run test` starts Postgres when it has to, then runs the suite.
- `mise run db:*` creates, migrates, rolls back and seeds the database.
- `mise run dev` runs the server, the worker and the asset watchers.

If no existing task covers what you need, say so and suggest a new script rather than working around it with a one
off command.

## Writing Rules

Review every prose output (posts, READMEs, docs, commit messages) against these rules before delivering:

1. Never use a metaphor, simile or other figure of speech which you are used to seeing in print.
2. Never use a long word where a short one will do.
3. If it is possible to cut a word out, always cut it out.
4. Never use the passive where you can use the active.
5. Never use a foreign phrase, a scientific word or a jargon word if you can think of an everyday English equivalent.
6. Never use emdash
7. Break any of these rules sooner than say anything outright barbarous.

[dry-operation]: https://dry-rb.org/gems/dry-operation
[Hanami]: https://hanamirb.org
[mise]: https://mise.jdx.dev
[Phlex]: https://www.phlex.fun
[Sidekiq]: https://sidekiq.org
