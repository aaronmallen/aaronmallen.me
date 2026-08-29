# frozen_string_literal: true

module Admin
  module Actions
    module Sessions
      class Destroy < Action
        include Deps[end_sessions: "operations.end_sessions"]

        def handle(request, response)
          end_sessions.call if auth_session(request).signed_in?
          path = end_session(request, response, return_to: request.params[:return_to])
          response.redirect_to(path || routes.path(:root))
        end

        private

        def sign_in_required? = false
      end
    end
  end
end
