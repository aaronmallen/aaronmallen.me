# frozen_string_literal: true

module Public
  module Actions
    module Posts
      class Feed < Action
        include Deps["settings", atom_feed: "operations.render_atom_feed", published_posts: "posts.queries.published"]

        config.formats.clear.accept :atom

        def handle(request, response)
          posts = published_posts.call
          halt_if_feed_unchanged(request, response, posts)

          response.body = atom_feed.call(
            posts,
            title: t(".title", owner: settings.owner[:name]),
            url: routes.url(:writing).to_s,
            feed_url: routes.url(:writing_feed).to_s,
          )
        end
      end
    end
  end
end
