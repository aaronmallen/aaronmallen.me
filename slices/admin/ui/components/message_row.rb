# frozen_string_literal: true

module Admin
  module UI
    module Components
      class MessageRow < Component
        READ_KEY = "r"
        UNREAD = Blog::Types::MessageStatus["unread"]

        prop :message, Blog::Types::Instance(ROM::Struct)
        prop :filter, Blog::Types::String
        prop :page, Blog::Types::Integer
        prop :bulk, Blog::Types::String

        def view_template
          div(id: "message-#{@message.id}", class: ["msg-item", ("unread" if unread?)], data: { key_row: true }) do
            BulkCheck(**pick)
            Form(action: path(:admin_open_message, id: @message.id), class: "msg-item-form") do
              input(type: "hidden", name: "status", value: @filter)
              input(type: "hidden", name: "page", value: @page)
              button(type: "submit", class: "msg-item-open", **keyed) { summary }
            end
          end
        end

        private

        def keyed
          return { data: { key_open: true } } unless unread?

          { aria: { keyshortcuts: READ_KEY }, data: { key_open: true, key: READ_KEY, key_label: t(".read_key") } }
        end

        def pick = { form: @bulk, value: @message.id, label: t(".pick", subject: @message.subject) }

        def summary
          span(class: "msg-item-head") do
            span(class: "sr-only") { t(".unread_mark") } if unread?
            span(class: "msg-item-title") { @message.subject }
            Moment(at: @message.received_at, format: :short)
          end
          span(class: "msg-item-from") { @message.reply_to }
          span(class: "msg-item-preview") { @message.body }
        end

        def unread? = @message.status == UNREAD
      end
    end
  end
end
