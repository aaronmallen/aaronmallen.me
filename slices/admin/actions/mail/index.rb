# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Index < Action
        COMPOSE = { values: Blog::Constants::EMPTY_HASH, errors: Blog::Constants::EMPTY_HASH }.freeze
        TASK = Blog::Types::RecordKind["task"]
        THREAD = Blog::Types::RecordKind["mail_thread"]

        include Deps[
          message_queries: "mail.repos.message_queries",
          person_queries: "contacts.repos.person_queries",
          record_link_queries: "links.repos.record_link_queries",
          save_draft: "mail.operations.save_draft",
          thread_queries: "mail.repos.thread_queries",
        ]

        def handle(request, response)
          message_queries.memoizing do
            show(request, response, draft: (compose(request) if request.params[:compose]),
                                    resume: request.params[:resume])
            response.render(view)
          end
        end

        private

        def compose(request)
          to = Blog::Types::OptionalText[request.params[:to]]

          to ? COMPOSE.merge(values: { to: }) : COMPOSE
        end

        def show(request, response, draft:, resume: nil)
          list = Helpers::MailList.from(request.params)
          threads = thread_queries.page_listed(requested_page(request, response), **Helpers::MailList.query(list))
          not_found(response) if threads.past_end?

          response[:list] = list
          response[:threads] = threads
          show_open(request, response)
          show_sources(response, list[:account])
          show_compose(response, draft, resume)
          show_marks(response)
        end

        def show_compose(response, draft, resume)
          response[:contacts] = person_queries.emailed
          response[:senders] = save_draft.senders(response[:accounts])
          drafted = save_draft.values(response[:open]) if resume && !draft
          response[:draft] = drafted ? { values: drafted, errors: Blog::Constants::EMPTY_HASH } : draft
        end

        def show_marks(response)
          ids = [*response[:threads].rows.map(&:id), response[:open]&.id].compact.uniq
          response[:reasons] = message_queries.reasons(ids)
          response[:tasks] = record_link_queries.partner_ids(THREAD, ids, TASK)
        end

        def show_open(request, response)
          id = Blog::Types::IdParam[request.params[:thread]]
          thread = id && thread_queries.by_id(id)

          response[:open] = thread
          response[:person] = thread&.reply_to && person_queries.by_email(thread.reply_to)
        end

        def show_sources(response, account)
          response[:accounts] = thread_queries.accounts
          response[:counts] = thread_queries.folder_counts(account:)
          response[:labels] = thread_queries.labels(response[:accounts])
          response[:unread] = thread_queries.unread_by_account
        end
      end
    end
  end
end
