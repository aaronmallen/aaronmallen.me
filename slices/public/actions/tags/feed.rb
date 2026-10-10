# frozen_string_literal: true

module Public
  module Actions
    module Tags
      class Feed < Action
        include Deps[
          atom_feed: "operations.render_atom_feed",
          post_queries: "posts.repos.post_queries",
        ]

        config.formats.clear.accept :atom
        answer_any_accept :atom

        def handle(request, response)
          tag = Blog::Types::Normalized::Tag.call(path_param(request, :tag)) { halt 404 }
          page = requested_page(request, response)
          redirect_to_own_path(request, response, :tag_feed, page, tag:)
          posts = post_queries.published_page_by_tag(tag, page)
          halt 404 if posts.rows.empty?
          version = version_feed_or_halt(request, response, posts)

          response.body = render_feed(version, tag)
        end

        private

        def render_feed(version, tag)
          atom_feed.call(
            version,
            title: t(".title", tag:, owner: settings.owner_name),
            html: :tag,
            feed: :tag_feed,
            params: { tag: },
          )
        end
      end
    end
  end
end
