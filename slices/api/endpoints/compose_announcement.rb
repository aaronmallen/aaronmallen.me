# frozen_string_literal: true

module API
  module Endpoints
    class ComposeAnnouncement < Endpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, announcement: Helpers::Schema::STRING }).freeze

      include Deps[
        compose_announcement: "posts.operations.compose_announcement",
        post_queries: "posts.repos.post_queries",
      ]

      def handle(id:)
        post = post_queries.by_id(id)
        return not_found(Helpers::Wording.missing("blog post", id)) if post.nil?

        Success(id: post.id, announcement: compose_announcement.call(post))
      end
    end
  end
end
