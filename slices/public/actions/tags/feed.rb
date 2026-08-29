# frozen_string_literal: true

module Public
  module Actions
    module Tags
      class Feed < Action
        include Deps[
          "settings",
          atom_feed: "operations.render_atom_feed",
          published_posts_by_tag: "posts.queries.published_by_tag",
        ]

        config.formats.clear.accept :atom

        def handle(request, response)
          tag = Blog::Types::Normalized::Tag.call(path_param(request, :tag)) { halt 404 }
          posts = published_posts_by_tag.call(tag)
          halt 404 if posts.empty?
          halt_if_feed_unchanged(request, response, posts)

          response.body = render_feed(posts, tag)
        end

        private

        def render_feed(posts, tag)
          atom_feed.call(
            posts,
            title: t(".title", tag:, owner: settings.owner[:name]),
            url: routes.url(:tag, tag:).to_s,
            feed_url: routes.url(:tag_feed, tag:).to_s,
          )
        end
      end
    end
  end
end
