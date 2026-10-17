# frozen_string_literal: true

module Admin
  module Helpers
    module TagList
      module_function

      def back(routes, scope, query, page)
        routes.path(:admin_tags, scope:, **(query.empty? ? {} : { q: query }), **Blog::Structs::Page.query(page))
      end
    end
  end
end
