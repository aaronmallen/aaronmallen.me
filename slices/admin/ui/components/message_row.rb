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
          UNREAD => [[READ, ".read", :pri], [SPAM, ".spam", :warn]],
          READ => [[UNREAD, ".unread", :pri], [SPAM, ".spam", :warn]],
          SPAM => [[UNREAD, ".unread", :pri]],
        }.freeze

        prop :message, Blog::Types::Instance(ROM::Struct)
        prop :filter, Blog::Types::String
        prop :bulk, Blog::Types::String.optional, default: nil

        def view_template
          ListItem(id: "message-#{@message.id}", title: @message.subject, pick:) do |item|
            item.body { p(class: "msg-body") { @message.body } }
            item.meta { p(class: "li-sub") { meta } }
            MOVES.fetch(@message.status).each { move(*it) }
          end
        end

        private

        def keyed(status)
          return Blog::Constants::EMPTY_HASH unless status == READ

          { aria: { keyshortcuts: READ_KEY }, data: { key: READ_KEY, key_label: t(".read_key") } }
        end

        def meta = Stamped(text: dotted(@message.reply_to, Stamped::MARK), at: @message.received_at)

        def move(status, label_key, variant)
          Form(action: path(:admin_mark_message, id: @message.id, status:)) do
            input(type: "hidden", name: "filter", value: @filter)
            Button(type: "submit", variant:, small: true, **keyed(status)) { t(label_key) }
          end
        end

        def pick = @bulk && { form: @bulk, value: @message.id, label: t(".pick", subject: @message.subject) }
      end
    end
  end
end
