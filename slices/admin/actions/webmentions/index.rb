# frozen_string_literal: true

module Admin
  module Actions
    module Webmentions
      class Index < Action
        include Deps[
          "settings",
          post_queries: "posts.repos.post_queries",
          webmention_queries: "social.repos.webmention_queries",
        ]

        def handle(request, response)
          filter = Blog::Types::WebmentionStatusParam[request.params[:status]]
          page = requested_page(request, response, settings.page_size[:admin])
          mentions = webmention_queries.page_by_status(filter, page)
          not_found(response) if mentions.past_end?

          response.render(view, **exposures(filter, mentions))
        end

        private

        def exposures(filter, mentions)
          posts = post_queries.summaries

          {
            counts: webmention_queries.count_by_status,
            filter:,
            inbox: { mentions:, slugs: posts.to_h { [it.id, it.slug] } },
            posts:,
            settings: webmention_queries.settings,
          }
        end
      end
    end
  end
end
