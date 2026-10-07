# frozen_string_literal: true

module Admin
  module Actions
    module Webmentions
      class Bulk < BulkAction
        DONE = {
          Blog::Types::WebmentionVerdict["approved"] => "webmentions_page.toasts.bulk.approved",
          Blog::Types::WebmentionVerdict["ignored"] => "webmentions_page.toasts.bulk.ignored",
          Blog::Types::WebmentionVerdict["spam"] => "webmentions_page.toasts.bulk.spam",
        }.freeze
        FAILED = "webmentions_page.toasts.bulk.failed"
        INVALID = "webmentions_page.toasts.bulk.invalid"
        REASONS = %i[not_found].freeze

        include Deps[
          "settings",
          operation: "social.operations.act_on_webmentions",
          webmention_queries: "social.repos.webmention_queries",
        ]

        private

        def back(request)
          status = Blog::Types::WebmentionStatusParam[request.params[:status]]
          page = landing(request) { webmention_queries.page_by_status(status, it).past_end? }

          routes.path(:admin_webmentions, status:, **Blog::Page.query(page))
        end

        def named(id) = { mention: "#{KEY}#{id}" }
      end
    end
  end
end
