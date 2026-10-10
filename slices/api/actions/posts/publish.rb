# frozen_string_literal: true

module API
  module Actions
    module Posts
      class Publish < Action
        SCOPE = Blog::Types::OAuthScope["publish"]

        include Deps[endpoint: "endpoints.publish_post"]

        def handle(request, response)
          answer(response, endpoint.call(body(request, response).merge("id" => record_id(request))))
        end
      end
    end
  end
end
