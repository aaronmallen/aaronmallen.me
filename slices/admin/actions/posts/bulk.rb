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

        include Deps[
          "settings",
          operation: "posts.operations.act_on_posts",
          post_queries: "posts.repos.post_queries",
        ]

        private

        def back(request)
          filter = Blog::Types::PostFilterParam[request.params[:status]]
          page = landing(request) { post_queries.by_filter(filter, it).past_end? }

          routes.path(:admin_posts, status: filter, **Blog::Page.query(page))
        end

        def details(request) = { tag: Blog::Types::Nullable::Tag[request.params[:tag]] }

        def named(id) = { post: post_queries.by_id(id)&.title || "#{KEY}#{id}" }

        def refusal(errors)
          case errors
            in { tag: [message, *] } then "tag_#{message}"
            else Blog::Contract::FORMAT
          end
        end
      end
    end
  end
end
