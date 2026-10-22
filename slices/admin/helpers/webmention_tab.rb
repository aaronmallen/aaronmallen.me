# frozen_string_literal: true

module Admin
  module Helpers
    module WebmentionTab
      WEBMENTIONS = "webmentions"

      module_function

      def webmentions(routes) = "#{routes.path(:admin_settings_webmentions)}##{WEBMENTIONS}"
    end
  end
end
