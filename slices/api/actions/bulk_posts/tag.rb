# frozen_string_literal: true

module API
  module Actions
    module BulkPosts
      class Tag < Action
        include Deps[endpoint: "endpoints.tag_posts"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
