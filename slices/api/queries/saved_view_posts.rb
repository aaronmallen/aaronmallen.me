# frozen_string_literal: true

require "dry/monads"

module API
  module Queries
    class SavedViewPosts
      include Dry::Monads[:result]
      include Deps["settings", posts_by_filter: "posts.queries.by_filter"]

      def call(filters, page: 1, **)
        chosen = Blog::Page.new(number: page, size: settings.page_size[:mcp])
        found = posts_by_filter.call(Blog::Types::PostFilterParam[filters["status"]], chosen)

        Success(rows: found.rows, **Blog::Paging.fields(found))
      end
    end
  end
end
