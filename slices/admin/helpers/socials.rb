# frozen_string_literal: true

module Admin
  module Helpers
    module Socials
      PEOPLE = "people"
      WEBMENTIONS = "webmentions"

      module_function

      def people(routes) = "#{routes.path(:admin_settings_socials)}##{PEOPLE}"

      def webmentions(routes) = "#{routes.path(:admin_settings_socials)}##{WEBMENTIONS}"
    end
  end
end
