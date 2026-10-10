# frozen_string_literal: true

module Admin
  module UI
    module Components
      class MessageBulk < Component
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
        prop :narrowed, Blog::Types::Hash

        def view_template
          BulkBar(id: ID, action: path(:admin_bulk_messages), label: t(".label"), fields:) do |bar|
            MARKS.except(@filter).each { |value, (icon, label)| bar.act(value, icon:, label: t(label)) }
            bar.act(DELETE, icon: "fa-regular fa-trash-can", label: t(".delete"), variant: :warn, data: confirm)
          end
        end

        private

        def confirm = { confirm: t(".confirm_delete") }

        def fields = { status: @filter, **@narrowed, **Blog::Structs::Page.query(@page) }
      end
    end
  end
end
