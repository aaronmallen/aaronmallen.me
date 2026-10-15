# frozen_string_literal: true

module API
  module Endpoints
    class TagPosts < BulkPostEndpoint
      ACT = Blog::Types::PostBulkAction["tag"]
      SCHEMA = Helpers::Schema.widen(Posts::BULK, tag: Posts::TAG).freeze

      include Deps[post_queries: "posts.repos.post_queries"]

      def handle(ids:, tag:) = acted(ids, tag:)

      private

      def public_in(fields) = ("a blog post in the list" if post_queries.shown?(fields[:ids]))
    end
  end
end
