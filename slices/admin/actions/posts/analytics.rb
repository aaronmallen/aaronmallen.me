# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Analytics < Action
        include Deps[build_post_analytics: "operations.build_post_analytics", post_queries: "posts.repos.post_queries"]

        def handle(request, response)
          post = post_queries.by_id(record_id(request))
          not_found(response) unless post
          range = Blog::Types::AnalyticsRangeParam[request.params[:range]]

          response.render(view, **build_post_analytics.call(post:, range:))
        end
      end
    end
  end
end
