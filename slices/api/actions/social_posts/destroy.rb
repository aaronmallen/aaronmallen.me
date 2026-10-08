# frozen_string_literal: true

module API
  module Actions
    module SocialPosts
      class Destroy < Action
        include Deps[endpoint: "endpoints.delete_social_post"]

        def handle(request, response) = answer(response, endpoint.call(id: record_id(request)))
      end
    end
  end
end
