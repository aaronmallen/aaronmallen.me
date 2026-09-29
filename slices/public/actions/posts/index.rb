# frozen_string_literal: true

module Public
  module Actions
    module Posts
      class Index < Action
        include Deps["settings", published_page: "posts.queries.published_page"]

        def handle(request, response)
          posts = published_page.call(requested_page(request, response, settings.page_size[:public]))
          not_found(response) if posts.past_end?

          response[:posts] = posts
        end
      end
    end
  end
end
