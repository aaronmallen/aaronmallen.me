# frozen_string_literal: true

module Admin
  module Actions
    module Security
      class SignOutDevice < Action
        SIGNED_OUT = "security_page.toasts.signed_out"

        include Deps[sign_out_device: "security.operations.sign_out_device"]

        def handle(request, response)
          halt :not_found if sign_out_device.call(request.params[:id]).failure?

          toast(response, SIGNED_OUT)
          response.redirect_to(routes.path(:admin_security))
        end
      end
    end
  end
end
