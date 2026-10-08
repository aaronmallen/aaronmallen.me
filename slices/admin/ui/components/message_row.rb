# frozen_string_literal: true

module Admin
  module UI
    module Components
      class MessageRow < Component
        READ = Blog::Types::MessageStatus["read"]
        READ_KEY = "r"
        SPAM = Blog::Types::MessageStatus["spam"]
        UNREAD = Blog::Types::MessageStatus["unread"]

        MOVES = {
          UNREAD => [[READ, ".read", nil], [SPAM, ".spam", :warn]],
          READ => [[UNREAD, ".unread", nil], [SPAM, ".spam", :warn]],
          SPAM => [[UNREAD, ".unread", nil]],
        }.freeze

        prop :message, Blog::Types::Instance(ROM::Struct)
        prop :filter, Blog::Types::String
        prop :bulk, Blog::Types::String

        def view_template
          div(id: "message-#{@message.id}", class: ["msg-item", ("unread" if @message.status == UNREAD)],
              data: { key_row: true }) do
            BulkCheck(**pick)
            a(class: "msg-item-open", href: "#read-#{@message.id}") { summary }
            div(class: "msg-item-acts") { MOVES.fetch(@message.status).each { move(*it) } }
          end
        end

        private

        def keyed(status)
          return Blog::Constants::EMPTY_HASH unless status == READ

          { aria: { keyshortcuts: READ_KEY }, data: { key: READ_KEY, key_label: t(".read_key") } }
        end

        def move(status, label_key, variant)
          Form(action: path(:admin_mark_message, id: @message.id, status:)) do
            input(type: "hidden", name: "filter", value: @filter)
            Button(type: "submit", variant:, small: true, **keyed(status)) { t(label_key) }
          end
        end

        def pick = { form: @bulk, value: @message.id, label: t(".pick", subject: @message.subject) }

        def summary
          p(class: "msg-item-head") do
            span(class: "sr-only") { t(".unread_mark") } if @message.status == UNREAD
            span(class: "msg-item-title") { @message.subject }
            Moment(at: @message.received_at, format: :short)
          end
          p(class: "msg-item-from") { @message.reply_to }
          p(class: "msg-item-preview") { @message.body }
        end
      end
    end
  end
end
