# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Open < Action
        READ = Blog::Types::MessageStatus["read"]
        UNREAD = Blog::Types::MessageStatus["unread"]

        include Redirect
        include Deps[
          change_thread: "mail.operations.change_thread",
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
          case change_thread.call(id, READ)
            in Success(_) | Failure(:gmail_failed) then nil
          end
        end
      end
    end
  end
end
