# frozen_string_literal: true

module API
  module Endpoints
    class TagPosts < BulkPostEndpoint
      ACT = Blog::Types::PostBulkAction["tag"]
      SCHEMA = Helpers::Schema.widen(Posts::BULK, tag: Posts::TAG).freeze

      def handle(ids:, tag:) = acted(ids, tag:)
    end
  end
end
