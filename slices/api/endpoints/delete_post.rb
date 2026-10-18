# frozen_string_literal: true

module API
  module Endpoints
    class DeletePost < Endpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, deleted: Helpers::Schema::BOOLEAN }).freeze

      include Deps[delete_post: "posts.operations.delete_post"]

      def handle(id:)
        case delete_post.call(id)
          in Success(post) then Success(id: post.id, deleted: true)
          in Failure(:not_found) then missing("blog post", id)
          in unmatched then unhandled(unmatched, "could not delete the blog post")
        end
      end
    end
  end
end
