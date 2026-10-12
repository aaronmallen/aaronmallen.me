# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Settings < Action
        include Deps[message_queries: "mail.repos.message_queries", thread_queries: "mail.repos.thread_queries"]

        def handle(_request, response)
          response.render(
            view,
            accounts: thread_queries.every_account, settings: message_queries.settings,
            waiting: message_queries.unread_count,
          )
        end
      end
    end
  end
end
