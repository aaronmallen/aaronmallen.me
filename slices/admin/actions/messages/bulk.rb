# frozen_string_literal: true

module Admin
  module Actions
    module Messages
      class Bulk < BulkAction
        DONE = {
          Blog::Types::MessageBulkAction["delete"] => "messages_page.toasts.bulk.deleted",
          Blog::Types::MessageBulkAction["read"] => "messages_page.toasts.bulk.read",
          Blog::Types::MessageBulkAction["tag"] => "messages_page.toasts.bulk.tagged",
          Blog::Types::MessageBulkAction["unread"] => "messages_page.toasts.bulk.unread",
          Blog::Types::MessageBulkAction["untag"] => "messages_page.toasts.bulk.untagged",
        }.freeze
        FAILED = "messages_page.toasts.bulk.failed"
        INVALID = "messages_page.toasts.bulk.invalid"
        REASONS = %i[not_found].freeze

        include Deps[
          message_queries: "contact.repos.message_queries",
          operation: "contact.operations.act_on_messages",
        ]

        private

        def back(request)
          list = Helpers::MessageList.from(request.params)
          page = landing(request) { message_queries.page_listed(it, **list).past_end? }

          Helpers::MessageList.back(routes, list, **Blog::Structs::Page.query(page))
        end

        def named(id)
          { message: [UI::Components::RecordKey.key(id), message_queries.by_id(id)&.subject].compact.join(" ") }
        end
      end
    end
  end
end
