# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Menu < Action
        INBOX = Blog::Types::TaskOrigin["inbox"]
        PRIVATE = Blog::Types::TagScope["private"]
        TASK = Blog::Types::RecordKind["task"]
        THREAD = Blog::Types::RecordKind["mail_thread"]

        include Deps[
          record_link_queries: "links.repos.record_link_queries",
          tag_queries: "tags.repos.tag_queries",
          thread_queries: "mail.repos.thread_queries",
        ]

        def handle(request, response)
          thread = thread_queries.by_id(record_id(request)) || halt(:not_found)

          response.render(view, thread:, list: list(request), return_to: back_here(request), **about(thread))
        end

        private

        def about(thread)
          id = thread.mail_account_id

          {
            account: thread_queries.every_account.find { it.id == id },
            labels: thread_queries.labels.fetch(id, []).map(&:first),
            tags: tag_queries.all_in(PRIVATE),
            task: record_link_queries.partner_ids(THREAD, [thread.id], TASK)[thread.id],
          }
        end

        def list(request)
          return { origin: INBOX } if request.params[:origin] == INBOX

          Helpers::MailList.from(request.params)
        end
      end
    end
  end
end
