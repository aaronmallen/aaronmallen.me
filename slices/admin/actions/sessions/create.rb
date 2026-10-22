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
          device_queries: "security.repos.device_queries",
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
          started = started_sign_in(request)
          return response.redirect_to(routes.path(:admin_root)) if started.nil? && just_signed_in?(request)

          callback(request, response, client, started)
        end

        private

        def callback(request, response, client, started)
          code = Blog::Types::Text[request.params[:code]]
          code_verifier = started_verifier(request, started, code)
          return fail_sign_in(request, response, :denied) if code_verifier.nil?

          finish_sign_in(request, response, check_account(client, request.params[:provider], code:, code_verifier:))
        end

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
          end
        end

        def just_signed_in?(request)
          device_queries.signed_in_since?(Blog::Types::UuidParam[request.cookies[Blog::DeviceCookie::KEY]],
                                          Time.now - 60)
        end

        def record(request, outcome)
          record_sign_in.call(
            request, outcome, provider: request.params[:provider].to_sym, device: request.cookies[Blog::DeviceCookie::KEY],
          )
        end

        def sign_in_client(provider) = { "github" => github, "google" => google }[provider]

        def sign_in_required? = false

        def signed_in(request, response, email)
          device = record(request, :signed_in)
          response.set_cookie(Blog::DeviceCookie::KEY, Blog::DeviceCookie.cookie(device))
          path = auth_session(request).sign_in(email, device:)
          response.redirect_to(path || routes.path(:admin_root))
        end

        def started_sign_in(request)
          Auth::ConnectState.new(request.session).take(Auth::ConnectState::SIGN_IN, request.params[:state])
        end

        def started_verifier(request, started, code)
          started["verifier"] if started && request.params[:error].nil? && !code.empty?
        end
      end
    end
  end
end
