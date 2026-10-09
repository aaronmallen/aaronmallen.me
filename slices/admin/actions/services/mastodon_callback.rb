# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class MastodonCallback < Action
        NAME = "Mastodon"
        PROVIDER = "mastodon"
        TOASTS = "services_page.toasts"

        include Deps[connect_mastodon: "operations.connect_mastodon"]

        def handle(request, response)
          started = Auth::ConnectState.new(request.session).take(PROVIDER, request.params[:state])
          return refuse(response, :refused) if started.nil?

          code = Blog::Types::Text[request.params[:code]]
          return refuse(response, :declined) if request.params[:error] || code.empty?

          case connect(started, code)
            in Success(connection) then connected(response, connection)
            in Failure(reason) then refuse(response, reason)
          end
        end

        private

        def connect(started, code)
          connect_mastodon.call(
            host: started.fetch("host"), code:, code_verifier: started.fetch("verifier"),
            redirect_uri: mastodon_service_callback_url,
          )
        end

        def connected(response, connection)
          toast(response, "#{TOASTS}.connected", name: NAME, account: connection.label)
          response.redirect_to(routes.path(:admin_services, selected: connection.id))
        end

        def refuse(response, reason)
          toast(response, "#{TOASTS}.#{reason}", name: NAME)
          response.redirect_to(routes.path(:admin_services))
        end
      end
    end
  end
end
