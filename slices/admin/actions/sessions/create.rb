# frozen_string_literal: true

module Admin
  module Actions
    module Sessions
      class Create < Action
        ENDS_SESSION = :wrong_account
        STATUSES = {
          denied: :unauthorized,
          provider_failed: :bad_gateway,
          wrong_account: :forbidden,
        }.freeze

        include Deps[
          failed_view: "ui.views.sessions.failed",
          github: "github.auth",
          github_connect: "actions.services.github_callback",
          google: "google.auth",
          google_connect: "actions.services.google_callback",
          linkedin_connect: "actions.services.linkedin_callback",
          mastodon_connect: "actions.services.mastodon_callback",
          record_sign_in: "security.operations.record_sign_in",
          sign_in: "operations.sign_in",
        ]

        def handle(request, response)
          provider = request.params[:provider]
          return connect_callback(provider).handle(request, response) if connecting?(request, provider)

          client = sign_in_client(provider) || not_found(response)
          code = Blog::Types::Text[request.params[:code]]
          code_verifier = started_verifier(request, code)
          return fail_sign_in(request, response, :denied) if code_verifier.nil?

          finish_sign_in(request, response, check_account(client, provider, code:, code_verifier:))
        end

        private

        def check_account(client, provider, code:, code_verifier:)
          sign_in.call(client:, code:, code_verifier:, redirect_uri: auth_callback_url(provider))
        end

        def connect_callback(provider)
          {
            "github" => github_connect, "google" => google_connect, "linkedin" => linkedin_connect,
            "mastodon" => mastodon_connect,
          }.fetch(provider)
        end

        def connecting?(request, provider)
          auth_session(request).signed_in? &&
            (sign_in_client(provider).nil? || Auth::ConnectState.new(request.session).held?(provider,
                                                                                            request.params[:state]))
        end

        def fail_sign_in(request, response, reason)
          record(request, Blog::Types::SignInOutcome.valid?(reason.to_s) ? reason : :unexpected)
          end_session(request, response) if reason == ENDS_SESSION
          response.status = STATUSES.fetch(reason, :internal_server_error)
          response.render(failed_view, reason:, provider: request.params[:provider].to_sym)
        end

        def finish_sign_in(request, response, result)
          case result
            in Success(email) then signed_in(request, response, email)
            in Failure(reason) then fail_sign_in(request, response, reason)
            else halt :internal_server_error
          end
        end

        def record(request, outcome) = record_sign_in.call(request, outcome, provider: request.params[:provider].to_sym)

        def sign_in_client(provider) = { "github" => github, "google" => google }[provider]

        def sign_in_required? = false

        def signed_in(request, response, email)
          record(request, :signed_in)
          path = auth_session(request).sign_in(email)
          response.redirect_to(path || routes.path(:admin_root))
        end

        def started_verifier(request, code)
          started = Auth::ConnectState.new(request.session).take(Auth::ConnectState::SIGN_IN, request.params[:state])
          started["verifier"] if started && request.params[:error].nil? && !code.empty?
        end
      end
    end
  end
end
