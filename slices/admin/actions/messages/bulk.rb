# frozen_string_literal: true

module Admin
  module Actions
    module Messages
      class Bulk < Action
        DONE = {
          Blog::Types::MessageBulkAction["delete"] => "messages_page.toasts.bulk.deleted",
          Blog::Types::MessageBulkAction["read"] => "messages_page.toasts.bulk.read",
          Blog::Types::MessageBulkAction["unread"] => "messages_page.toasts.bulk.unread",
        }.freeze
        FAILED = "messages_page.toasts.bulk.failed"
        INVALID = "messages_page.toasts.bulk.invalid"
        REASONS = %i[not_found].freeze

        include Actions::Bulk
        include Deps[
          "settings",
          message_by_id: "contact.queries.by_id",
          messages_by_status: "contact.queries.by_status",
          operation: "contact.operations.act_on_messages",
        ]

        private

        def back(request)
          status = Blog::Types::MessageStatusParam[request.params[:status]]
          page = landing(request) { messages_by_status.call(status, it).past_end? }

          routes.path(:admin_messages, status:, **Blog::Page.query(page))
        end

        def named(id) = { message: ["#{KEY}#{id}", message_by_id.call(id)&.subject].compact.join(" ") }
      end
    end
  end
end
