# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class MailCard < Component
          UNREAD = Blog::Types::MessageStatus["unread"]

          prop :threads, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :email, Blog::Types::String.optional

          def view_template
            Card(as: :aside, title: t(".title"), note: @threads.empty? ? t(".none") : @threads.size.to_s) do
              next Hint(class: "contact-mail-empty") { t(".empty", who: @email || t(".them")) } if @threads.empty?

              @threads.each { thread(it) }
            end
          end

          private

          def thread(thread)
            a(class: "contact-mail", href: path(:admin_mail, thread: thread.id)) do
              p(class: "contact-mail-subject") { thread.subject }
              p(class: "contact-mail-meta") do
                Moment(at: thread.received_at, format: :short)
                plain " · #{thread.account}"
                plain " · #{t('.unread')}" if thread.status == UNREAD
              end
            end
          end
        end
      end
    end
  end
end
