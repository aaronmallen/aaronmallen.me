# frozen_string_literal: true

module API
  module Actions
    module SocialPosts
      class Index < Action
        include Deps[endpoint: "endpoints.list_social_posts"]

        def handle(request, response) = answer(response, endpoint.call(paged_query(request, :from, :to, :queue)))
      end
    end
  end
end
