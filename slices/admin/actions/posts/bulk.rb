# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class Bulk < BulkAction
        DONE = {
          Blog::Types::PostBulkAction["delete"] => "posts_page.toasts.bulk.deleted",
          Blog::Types::PostBulkAction["tag"] => "posts_page.toasts.bulk.tagged",
        }.freeze
        FAILED = "posts_page.toasts.bulk.failed"
        INVALID = "posts_page.toasts.bulk.invalid"
        REASONS = %i[not_draft not_found].freeze

        include Redirect
        include Deps[
          operation: "posts.operations.act_on_posts",
          post_queries: "posts.repos.post_queries",
        ]

        private

        def named(id) = { post: post_queries.by_id(id)&.title || UI::Components::RecordKey.key(id) }
      end
    end
  end
end
