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
          FILTERS = { UNREAD => ".unread", READ => ".read", SPAM => ".spam" }.freeze

          def initialize(filter:, messages:)
            super()
            @filter = filter
            @messages = messages
          end

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub", count: @messages.size)) { filter_form }

            Card(title: t(".inbox")) do
              next Empty { t(EMPTIES.fetch(@filter)) } if @messages.empty?

              @messages.each { MessageRow(message: it, filter: @filter) }
            end
          end

          private

          def filter_form
            form(action: path(:admin_messages), method: "get", data: { autosubmit: "" }) do
              SegmentedControl(label: t(".filter"), name: "status", options: filter_options, selected: @filter)
              noscript { Button(type: "submit", small: true) { t(".apply") } }
            end
          end

          def filter_options = FILTERS.transform_values { t(it) }
        end
      end
    end
  end
end
