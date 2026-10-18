# frozen_string_literal: true

module Admin
  module Helpers
    module ServiceTab
      CLIENTS = "clients"
      SERVICES = "services"
      TOKENS = "tokens"

      module_function

      def clients(routes) = "#{routes.path(:admin_settings_services)}##{CLIENTS}"

      def services(routes, **) = "#{routes.path(:admin_settings_services, **)}##{SERVICES}"

      def tokens(routes) = "#{routes.path(:admin_settings_services)}##{TOKENS}"
    end
  end
end
