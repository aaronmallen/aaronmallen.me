# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Analytics < Action
        include Deps[build_post_analytics: "operations.build_post_analytics", post_by_id: "posts.queries.by_id"]

        def handle(request, response)
          post = post_by_id.call(record_id(request))
          not_found(response) unless post
          range = Blog::Types::AnalyticsRangeParam[request.params[:range]]

          response.render(view, **build_post_analytics.call(post:, range:))
        end
      end
    end
  end
end
