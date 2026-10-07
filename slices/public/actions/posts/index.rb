# frozen_string_literal: true

module Public
  module Actions
    module Posts
      class Index < Action
        include Deps["settings", post_queries: "posts.repos.post_queries"]

        share_with_caches

        def handle(request, response)
          posts = post_queries.published_page(requested_page(request, response, settings.page_size[:public]))
          not_found(response) if posts.past_end?

          response[:posts] = posts
        end
      end
    end
  end
end
