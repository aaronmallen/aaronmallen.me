# frozen_string_literal: true

return if Posts::Slice["repos.post_queries"].all.any?

save_post = Posts::Slice["operations.save_post"]

post = lambda do |title, body, intent: "draft", now: Time.now, publish_at: nil, **fields|
  params = { title:, slug: nil, summary: "", tags: "", body:, publish_at:, **fields }

  Seeds.unwrap(save_post.call(params, intent:, now:)).last
end

hanami = post.call(
  "Moving the blog to Hanami 3",
  <<~MARKDOWN,
    I moved this site from a static generator to [Hanami](https://example.org/hanami) this spring.

    Slices keep each feature apart, and [Phlex](https://example.org/phlex) keeps views in plain Ruby.
  MARKDOWN
  intent: "publish", now: Seeds.ago(20, hour: 9), tags: "hanami,ruby",
  summary: "Why I left the static generator behind.",
  syndication_enabled: Blog::Types::CHECKED, syndication_targets: %w[bluesky mastodon],
  syndication_body: "New post on moving this blog to Hanami.",
)

postgres = post.call(
  "Domains in Postgres",
  <<~MARKDOWN,
    A domain names a rule once, so every table that holds an email or a path checks it the same way.

    The [Postgres docs](https://example.org/postgres/domains) cover the syntax.
  MARKDOWN
  intent: "publish", now: Seeds.ago(9, hour: 14), tags: "postgres",
  summary: "Name a rule once and let every table use it.",
)

post.call(
  "Seeding a development database",
  "Every page needs data before you can see it. This post walks through seeds that use the app's own operations.",
  intent: "publish", publish_at: Blog::TimeZone.input_value(Time.now + (3 * 24 * Seeds::HOUR)), tags: "tooling",
  summary: "Seeds that go through the front door.",
)

post.call(
  "Providers, all the way down",
  <<~MARKDOWN,
    Every Hanami app has to talk to things it does not own: a database, a queue, an API. Providers are where that starts.

    ## What a provider is

    A provider starts a resource once and puts it in the container, so the rest of the app asks for it by name.

    ### Notes

    A provider can also stop what it started, which matters for workers.

    ## Registering one

    This one hands the app a Redis client.

    ```ruby config/providers/redis.rb
    Hanami.app.register_provider(:redis) do
      prepare { require "redis" }

      start { register "redis", Redis.new(url: target["settings"].redis_url) }

      stop { target["redis"].close }
    end
    ```

    ### Notes

    The key you register is the name every class asks for.

    ## Asking for it

    A class names what it needs with `Deps`, and the container fills it in.

    ```ruby
    class CountVisit
      include Deps["redis"]

      def call(path) = redis.incr("visits:\#{path}")
    end
    ```

    > If you cannot tell what a class needs from its first ten lines, the line between parts sits in the wrong place.

    ## Slices

    - **Each slice gets its own container.** A provider in `slices/admin` stays in admin unless you export it.
    - **Start order comes for free.** A provider that uses another asks for it, and Hanami starts that one first.

    ![The site's favicon](/favicon.ico "Any image with a title, alone on its line, renders as a figure.")

    ## Slices

    This heading repeats on purpose, so its id ends in a number.

    ## What I would change

    Keep a provider in the one slice that uses it. That rule shaped this codebase more than any refactor.
  MARKDOWN
  intent: "publish", now: Seeds.ago(3, hour: 10), tags: "hanami,ruby",
  summary: "A post that uses every part of the markdown renderer.",
)

draft = post.call(
  "Notes on tooling",
  <<~MARKDOWN,
    I keep every comand behind a task runner so I never have to remember the flags.

    It also means the the editor and CI run the same thing.
  MARKDOWN
  tags: "tooling,writing",
)

gone = post.call("A post I took down", "I said this better elsewhere.", intent: "publish", now: Seeds.ago(30, hour: 8))
Seeds.unwrap(Posts::Slice["operations.delete_post"].call(gone.id))

revised = <<~MARKDOWN
  I moved this site from a static generator to [Hanami](https://example.org/hanami) this spring.

  Slices keep each feature apart, and [Phlex](https://example.org/phlex) keeps views in plain Ruby.

  Update: the move also cut the build time in half.
MARKDOWN

Seeds.unwrap(
  save_post.call(
    {
      title: hanami.title, slug: hanami.slug, summary: hanami.summary, tags: "hanami,ruby", body: revised,
      publish_at: nil, edit_note: "Added a note on build time.",
    },
    id: hanami.id, intent: "save",
  ),
)

record_targets = Posts::Slice["operations.record_post_webmentions"]
Seeds.unwrap(record_targets.call(hanami.id, targets: %w[https://example.org/hanami https://example.org/phlex]))
Seeds.unwrap(record_targets.call(postgres.id, targets: %w[https://example.org/postgres/domains]))

Seeds.unwrap(
  Suggestions::Slice["operations.replace_post_edits"].call(
    draft.id,
    edits: [
      { original: "comand", replacement: "command", reason: "Spelling." },
      { original: "the the", replacement: "the", reason: "Repeated word." },
      { original: "so I never have to remember", replacement: "so I need not recall", reason: "Shorter." },
    ],
  ),
)

suggestion = Suggestions::Slice["repos.suggestion_queries"].for_post(draft.id)
first, second = suggestion.edits.sort_by(&:position)
Seeds.unwrap(Suggestions::Slice["operations.accept_suggestion_edits"].call(suggestion.id, ids: [first.id]))
Seeds.unwrap(Suggestions::Slice["operations.reject_suggestion_edits"].call(suggestion.id, ids: [second.id]))
