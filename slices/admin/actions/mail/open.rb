# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Open < BulkAction
        READ = Blog::Types::MessageStatus["read"]
        UNREAD = Blog::Types::MessageStatus["unread"]

        include Deps[
          mark_message: "mail.operations.mark_message",
          thread_queries: "mail.repos.thread_queries",
        ]

        def handle(request, response)
          id = record_id(request)
          thread = thread_queries.by_id(id) || halt(404)
          read(id) if thread.status == UNREAD

          response.redirect_to(back(request, id))
        end

        private

        def back(request, id)
          list = Helpers::MailList.from(request.params)
          page = landing(request) { thread_queries.page_listed(it, **Helpers::MailList.query(list)).past_end? }

          Helpers::MailList.back(routes, list, **Blog::Structs::Page.query(page), thread: id)
        end

        def read(id)
          case mark_message.call(id, READ)
            in Success(_) | Failure(:gmail_failed) then nil
            else halt 500
          end
        end
      end
    end
  end
end
