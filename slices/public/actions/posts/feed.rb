# frozen_string_literal: true

module Public
  module Actions
    module Posts
      class Feed < Action
        include Deps[
          atom_feed: "operations.render_atom_feed",
          post_queries: "posts.repos.post_queries",
        ]

        config.formats.clear.accept :atom
        answer_any_accept :atom

        def handle(request, response)
          posts = post_queries.published_page(requested_page(request, response))
          halt 404 if posts.past_end?
          version = version_feed_or_halt(request, response, posts)

          response.body = atom_feed.call(
            version,
            title: t(".title", owner: settings.owner_name),
            html: :writing,
            feed: :writing_feed,
          )
        end
      end
    end
  end
end
