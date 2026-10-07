# frozen_string_literal: true

require "dry/monads"

module API
  module Queries
    class SavedViewPosts
      include Dry::Monads[:result]
      include Deps["settings", post_queries: "posts.repos.post_queries"]

      def call(filters, page: 1, **)
        chosen = Blog::Page.new(number: page, size: settings.page_size[:mcp])
        found = post_queries.by_filter(Blog::Types::PostFilterParam[filters["status"]], chosen)

        Success(rows: found.rows, **Blog::Paging.fields(found))
      end
    end
  end
end
