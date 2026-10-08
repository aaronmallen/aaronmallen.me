# frozen_string_literal: true

module Admin
  module UI
    module Components
      class MessageBulk < Component
        ACT = "act"
        DELETE = Blog::Types::MessageBulkAction["delete"]
        ID = "message-bulk"
        READ = Blog::Types::MessageBulkAction["read"]
        UNREAD = Blog::Types::MessageBulkAction["unread"]
        MARKS = {
          READ => ["fa-regular fa-envelope-open", ".read"],
          UNREAD => ["fa-regular fa-envelope", ".unread"],
        }.freeze

        prop :filter, Blog::Types::String
        prop :page, Blog::Types::Integer

        def view_template
          BulkBar(id: ID, action: path(:admin_bulk_messages), label: t(".label"), fields:) do
            MARKS.except(@filter).each { |value, (icon, label)| act(value, icon, label) }
            act(DELETE, "fa-regular fa-trash-can", ".delete", variant: :warn, data: confirm)
          end
        end

        private

        def act(value, icon, label, variant: nil, data: nil)
          Button(type: "submit", variant:, small: true, name: ACT, value:, data:, icon:) { t(label) }
        end

        def confirm = { confirm: t(".confirm_delete"), confirm_styled: true }

        def fields = { status: @filter, **Blog::Structs::Page.query(@page) }
      end
    end
  end
end
