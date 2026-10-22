# frozen_string_literal: true

module Admin
  module Actions
    module Security
      class DismissSignIn < Action
        DISMISSED = "security_page.toasts.dismissed"

        include Deps[dismiss_sign_in: "security.operations.dismiss_sign_in"]

        def handle(request, response)
          halt :not_found if dismiss_sign_in.call(request.params[:id]).failure?

          toast(response, DISMISSED)
          response.redirect_to(routes.path(:admin_security))
        end
      end
    end
  end
end
