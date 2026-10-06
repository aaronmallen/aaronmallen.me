# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Messages
        class Index < View
          READ = Blog::Types::MessageStatus["read"]
          SPAM = Blog::Types::MessageStatus["spam"]
          UNREAD = Blog::Types::MessageStatus["unread"]

          EMPTIES = { UNREAD => ".empty.unread", READ => ".empty.read", SPAM => ".empty.spam" }.freeze
          FILTERS = {
            UNREAD => "ui.views.messages.index.unread",
            READ => "ui.views.messages.index.read",
            SPAM => "ui.views.messages.index.spam",
          }.freeze

          prop :count, Blog::Types::Integer
          prop :filter, Blog::Types::MessageStatus
          prop :messages, Blog::Types::Instance(Blog::Paged)

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub", count: @count)) { filter_form }

            Card(title: t(".inbox"), data: { key_list: true }) { rows }
            Pager(page: @messages, route: :admin_messages, params: { status: @filter })
          end

          private

          def filter_form
            FilterSwitch(
              action: path(:admin_messages),
              name: "status",
              options: FILTERS,
              selected: @filter,
              label: t(".filter"),
            )
          end

          def rows
            return Empty { t(EMPTIES.fetch(@filter)) } if @messages.rows.empty?

            MessageBulk(filter: @filter, page: @messages.number)
            @messages.rows.each { MessageRow(message: it, filter: @filter, bulk: MessageBulk::ID) }
          end
        end
      end
    end
  end
end
