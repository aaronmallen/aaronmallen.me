# frozen_string_literal: true

module API
  module Actions
    module SocialPosts
      class Send < Action
        SCOPE = Blog::Types::OAuthScope["publish"]

        include Deps[endpoint: "endpoints.send_social_post"]

        def handle(request, response)
          answer(response, endpoint.call(body(request, response).merge("id" => record_id(request))))
        end
      end
    end
  end
end
