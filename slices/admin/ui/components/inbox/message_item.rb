# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class MessageItem < Component
          AT = "@"
          ENCODED_AT = "%40"
          READ = Blog::Types::MessageStatus["read"]
          SPAM = Blog::Types::MessageStatus["spam"]

          prop :message, Blog::Types::Instance(ROM::Struct)

          def view_template
            ListItem(id: "message-#{@message.id}", title: @message.subject) do |item|
              item.body { p(class: "msg-body") { @message.body } }
              item.meta { p(class: "wm-meta") { meta } }
              actions
            end
          end

          private

          def actions
            Button(href: reply_href, small: true) { t(".reply") }
            mark(READ, ".read", :pri)
            mark(SPAM, ".spam", :warn)
          end

          def address = ERB::Util.url_encode(@message.reply_to).gsub(ENCODED_AT, AT)

          def mark(status, label_key, variant)
            Form(action: path(:admin_inbox_mark_message, id: @message.id, status:)) do
              Button(type: "submit", variant:, small: true) { t(label_key) }
            end
          end

          def meta
            Pill(color: :sand) { t(".kind") }
            span { Stamped(text: dotted(@message.reply_to, Stamped::MARK), at: @message.received_at) }
          end

          def reply_href = "mailto:#{address}?subject=#{ERB::Util.url_encode(t('.subject', subject: @message.subject))}"
        end
      end
    end
  end
end
