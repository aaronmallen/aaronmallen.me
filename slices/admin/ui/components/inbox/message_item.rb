# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class MessageItem < Component
          AT = "@"
          ENCODED_AT = "%40"
          FROM_INBOX = Blog::Types::TaskOrigin["inbox"]
          READ = Blog::Types::MessageStatus["read"]
          REASONS = Blog::Types::MailWaitReason.values.to_h { [it, ".reasons.#{it}"] }.freeze
          SPAM = Blog::Types::MessageStatus["spam"]

          prop :message, Blog::Types::Instance(ROM::Struct)
          prop :task, Blog::Types::Integer.optional, default: nil

          def view_template
            Row(id: "message-#{@message.id}", kind: :message, title: @message.subject) do |row|
              row.meta { meta }
              row.body { p(class: "msg-body inbox-row-body") { @message.body } }
              actions
            end
          end

          private

          def actions
            Button(href: reply_href, small: true, icon: "fa-solid fa-reply") { t(".reply") }
            mark(READ, ".read", :gh)
            mark(SPAM, ".spam", :warn)
            Inbox::Snooze(kind: "message", id: @message.id)
            Mail::TaskButton(thread: @message, task: @task, list: { origin: FROM_INBOX })
          end

          def address = ERB::Util.url_encode(@message.reply_to).gsub(ENCODED_AT, AT)

          def mark(status, label_key, variant)
            Form(action: path(:admin_inbox_mark_message, id: @message.id, status:), data: { morph: true }) do
              Button(type: "submit", variant:, small: true) { t(label_key) }
            end
          end

          def meta
            span { Stamped(text: Stamped::MARK, at: @message.received_at) }
            span { @message.account }
            span { @message.reply_to }
            span { t(REASONS.fetch(@message.reason)) } if @message.reason
          end

          def reply_href = "mailto:#{address}?subject=#{ERB::Util.url_encode(t('.subject', subject: @message.subject))}"
        end
      end
    end
  end
end
