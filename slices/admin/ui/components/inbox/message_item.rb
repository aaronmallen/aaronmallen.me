# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class MessageItem < Component
          AT = "@"
          ENCODED_AT = "%40"
          READ = Blog::Types::MessageStatus["read"]
          SEPARATOR = " · "
          SPAM = Blog::Types::MessageStatus["spam"]

          prop :message, Blog::Types::Instance(ROM::Struct)

          def view_template
            div(class: "li", data: { key_row: true }) do
              div(class: "li-main") do
                span(class: "li-title") { @message.subject }
                p(class: "msg-body") { @message.body }
                p(class: "wm-meta") { meta }
              end
              div(class: "li-side") { actions }
            end
          end

          private

          def actions
            a(class: "btn sm", href: reply_href) { t(".reply") }
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
            span { [@message.reply_to, l(Blog::TimeZone.local(@message.received_at), format: :medium)].join(SEPARATOR) }
          end

          def reply_href = "mailto:#{address}?subject=#{ERB::Util.url_encode(t('.subject', subject: @message.subject))}"
        end
      end
    end
  end
end
