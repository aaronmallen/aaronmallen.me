# frozen_string_literal: true

module API
  module Actions
    module DecisionTags
      class Destroy < Action
        SCOPE = Blog::Types::OAuthScope["write"]

        include Deps[endpoint: "endpoints.untag_decision"]

        def handle(request, response)
          answer(response, endpoint.call(id: record_id(request), tag: request.params[:tag]))
        end
      end
    end
  end
end
