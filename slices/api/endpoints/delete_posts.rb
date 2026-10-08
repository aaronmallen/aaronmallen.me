# frozen_string_literal: true

module API
  module Endpoints
    class DeletePosts < BulkPostEndpoint
      ACT = Blog::Types::PostBulkAction["delete"]
      DELETED = Helpers::Schema.object(
        { id: Helpers::Schema::INTEGER, title: Helpers::Schema::STRING, deleted: Helpers::Schema::BOOLEAN },
      ).freeze
      REPLY = Helpers::Schema.object({ posts: Helpers::Schema.list(DELETED) }).freeze
      SCHEMA = Posts::BULK

      def handle(ids:) = acted(ids)

      private

      def answered(posts) = posts.map { { id: it.id, title: it.title, deleted: true } }
    end
  end
end
