# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class IssueItem < Component
          LISTS = {
            Blog::Types::TaskFilter["today"] => ".lists.today",
            Blog::Types::TaskFilter["next"] => ".lists.next",
            Blog::Types::TaskFilter["someday"] => ".lists.someday",
          }.freeze
          TAG_SEPARATOR = ", "

          prop :task, Blog::Types::Instance(ROM::Struct)

          def view_template
            ListItem(title: @task.title, href: path(:admin_task, id: @task.id)) do |item|
              item.meta { p(class: "wm-meta") { meta } }
              actions
            end
          end

          private

          def actions
            LISTS.each { |filter, label_key| move(filter, label_key) unless filter == @task.place }
            tag
            Form(action: path(:admin_inbox_see_task, id: @task.id)) do
              Button(type: "submit", small: true) { t(".seen") }
            end
          end

          def meta
            Pill(color: :green) { t(".kind") }
            Tasks::SourceLink(source: @task.source)
            @task.tags.each { Tag(tag: it) }
            span { l(Blog::TimeZone.local(@task.created_at), format: :medium) }
          end

          def move(filter, label_key)
            list = t(label_key)

            Form(action: path(:admin_inbox_move_task, id: @task.id, filter:)) do
              Button(type: "submit", small: true, aria: { label: t(".move", list:) }) { list }
            end
          end

          def tag
            Form(action: path(:admin_inbox_tag_task, id: @task.id), class: "wm-spam") do
              Input(
                name: "tags", value: @task.tags.map(&:name).join(TAG_SEPARATOR), placeholder: t(".tags_placeholder"),
                aria: { label: t(".tags") },
              )
              Button(type: "submit", variant: :pri, small: true) { t(".tag") }
            end
          end
        end
      end
    end
  end
end
