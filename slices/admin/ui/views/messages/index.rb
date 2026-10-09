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
          prop :messages, Blog::Types::Instance(Blog::Structs::Paged)
          prop :open, Blog::Types::Instance(ROM::Struct).optional

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub", count: @count)) { filter_form }

            @messages.rows.empty? && !@open ? Card { empty } : panes
            Pager(page: @messages, route: :admin_messages, params: { status: @filter })
          end

          private

          def empty = Empty { t(EMPTIES.fetch(@filter)) }

          def filter_form
            FilterSwitch(
              action: path(:admin_messages),
              name: "status",
              options: FILTERS,
              selected: @filter,
              label: t(".filter"),
            )
          end

          def letter
            return Empty { t(".pick") } unless @open

            MessageLetter(message: @open, filter: @filter, page: @messages.number)
          end

          def panes
            div(class: "msg-panes") do
              Card(class: "msg-list") do
                MessageBulk(filter: @filter, page: @messages.number)
                @messages.rows.empty? ? empty : rows
              end
              Card(class: "msg-pane") { letter }
            end
          end

          def rows
            div(data: { key_list: true }) do
              @messages.rows.each do |message|
                MessageRow(message:, filter: @filter, page: @messages.number, bulk: MessageBulk::ID)
              end
            end
          end
        end
      end
    end
  end
end
