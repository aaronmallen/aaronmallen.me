# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class GitHubCallback < Action
        NAME = "GitHub"
        PROVIDER = "github"
        TOASTS = "services_page.toasts"

        include Deps[connect_github: "operations.connect_github"]

        def handle(request, response)
          verifier = Auth::ConnectState.new(request.session).take(PROVIDER, request.params[:state])
          return refuse(response, :refused) if verifier.nil?

          code = Blog::Types::Text[request.params[:code]]
          return refuse(response, :declined) if request.params[:error] || code.empty?

          case connect(code, verifier)
            in Success(connection) then connected(response, connection)
            in Failure(reason) then refuse(response, reason)
          end
        end

        private

        def connect(code, code_verifier)
          connect_github.call(code:, code_verifier:, redirect_uri: github_service_callback_url)
        end

        def connected(response, connection)
          toast(response, "#{TOASTS}.connected", name: NAME, account: connection.label)
          response.redirect_to(routes.path(:admin_services, selected: connection.id))
        end

        def refuse(response, reason)
          toast(response, "#{TOASTS}.#{reason}")
          response.redirect_to(routes.path(:admin_services))
        end
      end
    end
  end
end
