# frozen_string_literal: true

module Admin
  module Actions
    module Sessions
      class Create < Action
        ENDS_SESSION = :wrong_account
        STATUSES = {
          denied: 401,
          github_failed: 502,
          wrong_account: 403,
        }.freeze
        UNEXPECTED = 500

        include Deps[failed_view: "ui.views.sessions.failed", sign_in: "operations.sign_in"]

        def handle(request, response)
          code = Blog::Types::Text[request.params[:code]]
          return fail_sign_in(request, response, :denied) unless callback_valid?(request, code)

          case sign_in.call(code:, redirect_uri: github_callback_url)
            in Success(github_user_id)
              path = auth_session(request).sign_in(github_user_id)
              response.redirect_to(path || routes.path(:admin_root))
            in Failure(reason)
              fail_sign_in(request, response, reason)
            else halt 500
          end
        end

        private

        def callback_valid?(request, code)
          auth_session(request).state?(request.params[:state]) && request.params[:error].nil? && !code.empty?
        end

        def fail_sign_in(request, response, reason)
          end_session(request, response) if reason == ENDS_SESSION
          response.status = STATUSES.fetch(reason, UNEXPECTED)
          response.render(failed_view, reason:)
        end

        def sign_in_required? = false
      end
    end
  end
end
