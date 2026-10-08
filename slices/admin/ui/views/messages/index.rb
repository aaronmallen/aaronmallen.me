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

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub", count: @count)) { filter_form }

            @messages.rows.empty? ? Card { Empty { t(EMPTIES.fetch(@filter)) } } : panes
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

          def letter(message)
            article(id: "read-#{message.id}", class: "msg-letter") do
              p(class: "inbox-meta") do
                span { message.reply_to }
                Moment(at: message.received_at)
              end
              h2(class: "msg-letter-title") { message.subject }
              p(class: "msg-body msg-letter-body") { message.body }
            end
          end

          def panes
            div(class: "msg-panes") do
              Card(class: "msg-list") do
                MessageBulk(filter: @filter, page: @messages.number)
                div(data: { key_list: true }) do
                  @messages.rows.each { MessageRow(message: it, filter: @filter, bulk: MessageBulk::ID) }
                end
              end
              Card(class: "msg-pane") { @messages.rows.each { letter(it) } }
            end
          end
        end
      end
    end
  end
end
