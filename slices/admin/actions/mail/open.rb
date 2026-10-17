# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Open < Action
        READ = Blog::Types::MessageStatus["read"]
        UNREAD = Blog::Types::MessageStatus["unread"]

        include Redirect
        include Deps[
          mark_message: "mail.operations.mark_message",
          thread_queries: "mail.repos.thread_queries",
        ]

        def handle(request, response)
          id = record_id(request)
          thread = thread_queries.by_id(id) || halt(:not_found)
          read(id) if thread.status == UNREAD

          response.redirect_to(listed(request, thread: id))
        end

        private

        def read(id)
          case mark_message.call(id, READ)
            in Success(_) | Failure(:gmail_failed) then nil
            else halt :internal_server_error
          end
        end
      end
    end
  end
end
