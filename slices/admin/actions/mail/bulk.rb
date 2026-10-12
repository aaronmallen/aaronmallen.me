# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Bulk < BulkAction
        ACT = Blog::Types::MessageBulkAction
        DONES = %w[archive delete inbox read spam star tag trash unread untag].freeze
        DONE = DONES.to_h { [ACT[it], "mail_page.toasts.bulk.#{it}"] }.freeze
        FAILED = "mail_page.toasts.bulk.failed"
        INVALID = "mail_page.toasts.bulk.invalid"
        LABELED = "mail_page.toasts.bulk.label"
        REASONS = %i[gmail_failed not_found].freeze
        SKIPPED = "mail_page.toasts.bulk.label_skipping"

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

        def done(request, response, records)
          act = request.params[:act]
          return labeled(request, response, records) if act == ACT["label"]

          act = request.params[:to] if act == ACT["move"]
          toast(response, DONE.fetch(act), count: records.size, **details(request))
        end

        def labeled(request, response, records)
          count = records.compact.size
          skipped = records.size - count
          label = request.params[:label].split(":", 2).last

          toast(response, skipped.positive? && count.positive? ? SKIPPED : LABELED, count:, skipped:, label:)
        end

        def named(id)
          { thread: [UI::Components::RecordKey.key(id), thread_queries.by_id(id)&.subject].compact.join(" ") }
        end
      end
    end
  end
end
