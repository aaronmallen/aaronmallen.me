# frozen_string_literal: true

module Admin
  module Actions
    module Maintenance
      class Activate < Action
        include Deps["operations.activate_maintenance"]

        def handle(_request, response)
          case activate_maintenance.call
            in Success(pass) then owner_cookie(response, pass)
            in Failure(:unwritable) then toast(response, "settings_page.toasts.maintenance_unwritable")
          end
          response.redirect_to(routes.path(:admin_security))
        end

        private

        def owner_cookie(response, pass)
          response.set_cookie(
            Blog::Maintenance::COOKIE,
            value: pass, httponly: true, path: "/", same_site: :strict, secure: Hanami.env?(:production),
          )
        end
      end
    end
  end
end
