# frozen_string_literal: true

module Public
  module Actions
    module Tags
      class Feed < Action
        include Deps[
          "settings",
          atom_feed: "operations.render_atom_feed",
          published_page_by_tag: "posts.queries.published_page_by_tag",
        ]

        config.formats.clear.accept :atom
        answer_any_accept :atom

        def handle(request, response)
          tag = Blog::Types::Normalized::Tag.call(path_param(request, :tag)) { halt 404 }
          posts = published_page_by_tag.call(tag, requested_page(request, response, settings.page_size[:public]))
          halt 404 if posts.rows.empty?
          halt_if_feed_unchanged(request, response, posts)

          response.body = render_feed(posts, tag)
        end

        private

        def render_feed(posts, tag)
          atom_feed.call(
            posts,
            title: t(".title", tag:, owner: settings.owner[:name]),
            html: :tag,
            feed: :tag_feed,
            params: { tag: },
          )
        end
      end
    end
  end
end
