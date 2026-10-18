# frozen_string_literal: true

module Admin
  module Helpers
    module TagList
      RULES = "task-rules"
      TAGS = "tags"

      module_function

      def back(routes, scope, query, page)
        params = { scope:, **(query.empty? ? {} : { q: query }), **Blog::Structs::Page.query(page) }

        "#{routes.path(:admin_settings_tagging, **params)}##{TAGS}"
      end

      def rules(routes) = "#{routes.path(:admin_settings_tagging)}##{RULES}"
    end
  end
end
