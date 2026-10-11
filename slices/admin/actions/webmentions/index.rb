# frozen_string_literal: true

module Admin
  module Actions
    module Webmentions
      class Index < Action
        include Deps[
          post_queries: "posts.repos.post_queries",
          webmention_queries: "social.repos.webmention_queries",
        ]

        def handle(request, response)
          filter = Blog::Types::WebmentionStatusParam[request.params[:status]]
          page = requested_page(request, response)
          mentions = webmention_queries.page_by_status(filter, page)
          not_found(response) if mentions.past_end?

          response.render(view, **exposures(filter, mentions))
        end

        private

        def exposures(filter, mentions)
          slugs = post_queries.summaries.to_h { [it.id, it.slug] }

          { counts: webmention_queries.count_by_status, filter:, inbox: { mentions:, slugs: } }
        end
      end
    end
  end
end
