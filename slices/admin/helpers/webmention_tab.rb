# frozen_string_literal: true

module Admin
  module Helpers
    module WebmentionTab
      PEOPLE = "people"
      WEBMENTIONS = "webmentions"

      module_function

      def people(routes) = "#{routes.path(:admin_settings_webmentions)}##{PEOPLE}"

      def webmentions(routes) = "#{routes.path(:admin_settings_webmentions)}##{WEBMENTIONS}"
    end
  end
end
