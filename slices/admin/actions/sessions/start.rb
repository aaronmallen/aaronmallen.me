# frozen_string_literal: true

module Admin
  module Actions
    module Sessions
      class Start < Action
        GOOGLE = "google"

        include Deps[failed_view: "ui.views.sessions.failed", github: "github.auth", google: "google.auth"]

        def handle(request, response)
          provider = request.params[:provider]
          client = provider == GOOGLE ? google : github
          return not_configured(request, response) unless client.configured?

          started = Auth::ConnectState.new(request.session).start(Auth::ConnectState::SIGN_IN)
          response.redirect_to(client.sign_in_url(redirect_uri: auth_callback_url(provider), **started))
        end

        private

        def not_configured(request, response)
          response.status = :service_unavailable
          response.render(failed_view, reason: :not_configured, provider: request.params[:provider].to_sym)
        end

        def sign_in_required? = false
      end
    end
  end
end
