# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Destroy < BulkAction
        DELETED = "mail_page.toasts.deleted"

        include Deps[
          delete_message: "mail.operations.delete_message",
          thread_queries: "mail.repos.thread_queries",
        ]

        def handle(request, response)
          settle(response, delete_message.call(record_id(request)), DELETED, back(request))
        end

        private

        def back(request)
          list = Helpers::MailList.from(request.params)
          page = landing(request) { thread_queries.page_listed(it, **Helpers::MailList.query(list)).past_end? }

          Helpers::MailList.back(routes, list, **Blog::Structs::Page.query(page))
        end
      end
    end
  end
end
