# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Bulk < BulkAction
        DONE = {
          Blog::Types::MessageBulkAction["delete"] => "mail_page.toasts.bulk.deleted",
          Blog::Types::MessageBulkAction["read"] => "mail_page.toasts.bulk.read",
          Blog::Types::MessageBulkAction["tag"] => "mail_page.toasts.bulk.tagged",
          Blog::Types::MessageBulkAction["unread"] => "mail_page.toasts.bulk.unread",
          Blog::Types::MessageBulkAction["untag"] => "mail_page.toasts.bulk.untagged",
        }.freeze
        FAILED = "mail_page.toasts.bulk.failed"
        INVALID = "mail_page.toasts.bulk.invalid"
        REASONS = %i[not_found].freeze

        include Deps[
          act_on_messages: "mail.operations.act_on_messages",
          thread_queries: "mail.repos.thread_queries",
        ]

        private

        def act(params) = act_on_messages.call(params)

        def back(request)
          list = Helpers::MailList.from(request.params)
          page = landing(request) { thread_queries.page_listed(it, **Helpers::MailList.query(list)).past_end? }

          Helpers::MailList.back(routes, list, **Blog::Structs::Page.query(page))
        end

        def named(id)
          { thread: [UI::Components::RecordKey.key(id), thread_queries.by_id(id)&.subject].compact.join(" ") }
        end
      end
    end
  end
end
