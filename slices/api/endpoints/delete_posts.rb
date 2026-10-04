# frozen_string_literal: true

module API
  module Endpoints
    class DeletePosts < BulkPostEndpoint
      ACT = Blog::Types::PostBulkAction["delete"]
      DELETED = Schema.object({ id: Schema::INTEGER, title: Schema::STRING, deleted: Schema::BOOLEAN }).freeze
      REPLY = Schema.object({ posts: Schema.list(DELETED) }).freeze
      SCHEMA = Posts::BULK

      def handle(ids:) = acted(ids)

      private

      def answered(posts) = posts.map { { id: it.id, title: it.title, deleted: true } }
    end
  end
end
