# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class LinkedInCallback < Action
        NAME = "LinkedIn"
        PROVIDER = Blog::Types::ServiceProvider["linkedin"]
        TOASTS = "services_page.toasts"

        include Deps[connect_linkedin: "operations.connect_linkedin"]

        def handle(request, response)
          started = Auth::ConnectState.new(request.session).take(PROVIDER, request.params[:state])
          return refuse(response, :refused) if started.nil?

          code = Blog::Types::Text[request.params[:code]]
          return refuse(response, :declined) if request.params[:error] || code.empty?

          case connect(code)
            in Success(connection) then connected(response, connection)
            in Failure(reason) then refuse(response, reason)
          end
        end

        private

        def connect(code) = connect_linkedin.call(code:, redirect_uri: auth_callback_url(PROVIDER))

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
