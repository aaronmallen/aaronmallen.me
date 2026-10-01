# frozen_string_literal: true

module Public
  module Actions
    module Posts
      class Feed < Action
        include Deps[
          "settings",
          atom_feed: "operations.render_atom_feed",
          published_page: "posts.queries.published_page",
        ]

        config.formats.clear.accept :atom
        answer_any_accept :atom

        def handle(request, response)
          posts = published_page.call(requested_page(request, response, settings.page_size[:public]))
          halt 404 if posts.past_end?
          version = version_feed_or_halt(request, response, posts)

          response.body = atom_feed.call(
            version,
            title: t(".title", owner: settings.owner[:name]),
            html: :writing,
            feed: :writing_feed,
          )
        end
      end
    end
  end
end
