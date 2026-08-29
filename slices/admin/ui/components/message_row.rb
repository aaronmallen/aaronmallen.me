# frozen_string_literal: true

module Admin
  module UI
    module Components
      class MessageRow < Component
        READ = Blog::Types::MessageStatus["read"]
        SEPARATOR = " · "
        SPAM = Blog::Types::MessageStatus["spam"]
        UNREAD = Blog::Types::MessageStatus["unread"]

        MOVES = {
          UNREAD => [[READ, ".read", :pri], [SPAM, ".spam", :warn]],
          READ => [[UNREAD, ".unread", :pri], [SPAM, ".spam", :warn]],
          SPAM => [[UNREAD, ".unread", :pri]],
        }.freeze

        prop :message, Blog::Types::Instance(ROM::Struct)
        prop :filter, Blog::Types::String

        def view_template
          div(class: "li") do
            div(class: "li-main") do
              span(class: "li-title") { @message.subject }
              p(class: "msg-body") { @message.body }
              p(class: "li-sub") { meta }
            end
            div(class: "li-side") { MOVES.fetch(@message.status).each { move(*it) } }
          end
        end

        private

        def meta = [@message.reply_to, l(Blog::TimeZone.local(@message.received_at), format: :medium)].join(SEPARATOR)

        def move(status, label_key, variant)
          Form(action: path(:admin_mark_message, id: @message.id, status:)) do
            input(type: "hidden", name: "filter", value: @filter)
            Button(type: "submit", variant:, small: true) { t(label_key) }
          end
        end
      end
    end
  end
end
