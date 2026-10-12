# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Index < Action
        COMPOSE = { values: Blog::Constants::EMPTY_HASH, errors: Blog::Constants::EMPTY_HASH }.freeze
        TASK = Blog::Types::RecordKind["task"]
        THREAD = Blog::Types::RecordKind["mail_thread"]

        include Deps[
          person_queries: "social.repos.person_queries",
          record_link_queries: "links.repos.record_link_queries",
          send_mail: "mail.operations.send_mail",
          thread_queries: "mail.repos.thread_queries",
        ]

        def handle(request, response)
          show(request, response, draft: (COMPOSE if request.params[:compose]))
        end

        private

        def show(request, response, draft:)
          list = Helpers::MailList.from(request.params)
          threads = thread_queries.page_listed(requested_page(request, response), **Helpers::MailList.query(list))
          not_found(response) if threads.past_end?

          response[:list] = list
          response[:threads] = threads
          show_compose(response, draft)
          show_sources(response, list[:account])
          show_open(request, response)
          show_tasks(response)
        end

        def show_compose(response, draft)
          response[:senders] = send_mail.senders
          response[:draft] = draft
        end

        def show_open(request, response)
          id = Blog::Types::IdParam[request.params[:thread]]
          thread = id && thread_queries.by_id(id)

          response[:open] = thread
          response[:person] = thread&.sender && person_queries.by_name(thread.sender)
        end

        def show_sources(response, account)
          response[:accounts] = thread_queries.accounts
          response[:counts] = thread_queries.folder_counts(account:)
          response[:labels] = thread_queries.labels
          response[:unread] = thread_queries.unread_by_account
        end

        def show_tasks(response)
          ids = [*response[:threads].rows.map(&:id), response[:open]&.id].compact.uniq
          response[:tasks] = record_link_queries.partner_ids(THREAD, ids, TASK)
        end
      end
    end
  end
end
