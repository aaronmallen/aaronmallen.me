# frozen_string_literal: true

module Admin
  module Actions
    module Sessions
      class New < Action
        include Deps[github: "github.auth", failed_view: "ui.views.sessions.failed"]

        def handle(request, response)
          return not_configured(response) unless github.configured?

          state = auth_session(request).start_sign_in
          response.redirect_to(github.authorize_url(redirect_uri: github_callback_url, state:))
        end

        private

        def not_configured(response)
          response.status = 503
          response.render(failed_view, reason: :not_configured)
        end

        def sign_in_required? = false
      end
    end
  end
end
