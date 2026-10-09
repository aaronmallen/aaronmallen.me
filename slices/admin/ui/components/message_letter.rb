# frozen_string_literal: true

module Admin
  module UI
    module Components
      class MessageLetter < Component
        READ = Blog::Types::MessageStatus["read"]
        SPAM = Blog::Types::MessageStatus["spam"]
        UNREAD = Blog::Types::MessageStatus["unread"]

        prop :message, Blog::Types::Instance(ROM::Struct)
        prop :filter, Blog::Types::String
        prop :page, Blog::Types::Integer

        def view_template
          article(id: "read-#{@message.id}", class: "msg-letter") do
            p(class: "inbox-meta") do
              span { @message.reply_to }
              Moment(at: @message.received_at)
              StatusPill(status: :spam) if spam?
            end
            h2(class: "msg-letter-title") { @message.subject }
            div(class: "msg-letter-acts") { spam? ? spam_acts : acts }
            p(class: "msg-body msg-letter-body") { @message.body }
          end
        end

        private

        def acts
          @message.status == UNREAD ? mark(READ, ".mark_read") : mark(UNREAD, ".mark_unread")
          div(class: "msg-letter-far") do
            mark(SPAM, ".spam", variant: :warn)
            delete(".delete", ".confirm_delete")
          end
        end

        def delete(label_key, confirm_key)
          Form(action: path(:admin_delete_message, id: @message.id)) do
            input(type: "hidden", name: "status", value: @filter)
            input(type: "hidden", name: "page", value: @page)
            Button(type: "submit", variant: :warn, small: true, data: { confirm: t(confirm_key) }) { t(label_key) }
          end
        end

        def mark(status, label_key, variant: nil)
          Form(action: path(:admin_mark_message, id: @message.id, status:)) do
            input(type: "hidden", name: "filter", value: @filter)
            input(type: "hidden", name: "open", value: @message.id)
            Button(type: "submit", variant:, small: true) { t(label_key) }
          end
        end

        def spam? = @message.status == SPAM

        def spam_acts
          div(class: "msg-letter-far") do
            mark(READ, ".not_spam")
            delete(".delete_forever", ".confirm_delete_forever")
          end
        end
      end
    end
  end
end
