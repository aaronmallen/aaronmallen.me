# auto_register: false
# frozen_string_literal: true

module Admin
  class ServiceCallback < Action
    TOASTS = "services_page.toasts"

    def handle(request, response)
      started = Auth::ConnectState.new(request.session).take(self.class::PROVIDER, request.params[:state])
      return refuse(response, :refused) if started.nil?

      code = Blog::Types::Text[request.params[:code]]
      return refuse(response, :declined) if request.params[:error] || code.empty?

      case connect(started, code)
        in Success(connection) then connected(response, connection)
        in Failure(reason) then refuse(response, reason)
      end
    end

    private

    def connected(response, connection)
      toast(response, "#{TOASTS}.connected", name: self.class::NAME, account: connection.label)
      response.redirect_to(routes.path(:admin_services, selected: connection.id))
    end

    def redirect_uri = auth_callback_url(self.class::PROVIDER)

    def refuse(response, reason)
      toast(response, "#{TOASTS}.#{reason}", name: self.class::NAME)
      response.redirect_to(routes.path(:admin_services))
    end
  end
end
