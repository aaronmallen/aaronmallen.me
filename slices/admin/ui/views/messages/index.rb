# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Messages
        class Index < View
          INBOX = Blog::Types::MessageFilter["inbox"]
          READ = Blog::Types::MessageFilter["read"]
          SEARCH_ID = "messages-search"
          SPAM = Blog::Types::MessageFilter["spam"]
          TAG_ID = "messages-tag"
          UNREAD = Blog::Types::MessageFilter["unread"]

          EMPTIES = Blog::Types::MessageFilter.values.to_h { [it, ".empty.#{it}"] }.freeze
          FILTERS = {
            INBOX => "ui.views.messages.index.inbox",
            UNREAD => "ui.views.messages.index.unread",
            READ => "ui.views.messages.index.read",
            SPAM => "ui.views.messages.index.spam",
          }.freeze

          prop :count, Blog::Types::Integer
          prop :list, Blog::Types::Hash
          prop :messages, Blog::Types::Instance(Blog::Structs::Paged)
          prop :open, Blog::Types::Instance(ROM::Struct).optional
          prop :tag_names, Blog::Types::Array.of(Blog::Types::String)
          prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub", count: @count)) { filter_form }

            @messages.rows.empty? && !@open ? Card { empty } : panes
            Pager(page: @messages, route: :admin_messages, params: @list)
          end

          private

          def empty = Empty { t(narrowed.empty? ? EMPTIES.fetch(filter) : ".no_match") }

          def filter = @list[:status]

          def filter_form
            AutoForm(action: path(:admin_messages), role: "search", class: "msg-filters") do
              search_field
              SegmentedControl(label: t(".filter"), name: "status", options:, selected: filter)
              tag_field unless @tag_names.empty?
            end
          end

          def letter
            return Empty { t(".pick") } unless @open

            MessageLetter(message: @open, filter:, page: @messages.number, narrowed:, tags: @tags)
          end

          def narrowed = @list.except(:status)

          def options = FILTERS.transform_values { t(it) }

          def panes
            div(class: "msg-panes") do
              Card(class: "msg-list") do
                MessageBulk(filter:, page: @messages.number, narrowed:)
                @messages.rows.empty? ? empty : rows
              end
              Card(class: "msg-pane") { letter }
            end
          end

          def rows
            div(data: { key_list: true }) do
              @messages.rows.each do |message|
                MessageRow(message:, filter:, page: @messages.number, bulk: MessageBulk::ID, narrowed:)
              end
            end
          end

          def search_field
            label(class: "sr-only", for: SEARCH_ID) { t(".search") }
            Input(type: "search", id: SEARCH_ID, name: "search", value: @list[:search], placeholder: t(".placeholder"))
          end

          def tag_field
            label(class: "sr-only", for: TAG_ID) { t(".tag") }
            Select(id: TAG_ID, name: "tag", options: tag_options, selected: @list[:tag])
          end

          def tag_options = { "" => t(".all_tags"), **@tag_names.to_h { [it, it] } }
        end
      end
    end
  end
end
