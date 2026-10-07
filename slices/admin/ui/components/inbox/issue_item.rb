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
          ORIGIN = Blog::Types::TaskOrigin["inbox"]

          prop :task, Blog::Types::Instance(ROM::Struct)

          def view_template
            ListItem(id: "issue-#{@task.id}", title: @task.title, href: path(:admin_task, id: @task.id)) do |item|
              item.meta { p(class: "wm-meta") { meta } }
              actions
            end
          end

          private

          def actions
            LISTS.each { |filter, label_key| move(filter, label_key) unless filter == @task.place }
            edit
            Form(action: path(:admin_inbox_see_task, id: @task.id)) do
              Button(type: "submit", small: true) { t(".seen") }
            end
            Inbox::Snooze(kind: "task", id: @task.id)
          end

          def edit
            href = path(:admin_edit_task, id: @task.id, origin: ORIGIN)

            Button(href:, data: { task_open_edit: true }, small: true) { t(".edit") }
          end

          def meta
            Pill(color: :green) { t(".kind") }
            Tasks::SourceLink(source: @task.source)
            @task.tags.each { Tag(tag: it) }
            Moment(at: @task.created_at)
          end

          def move(filter, label_key)
            list = t(label_key)

            Form(action: path(:admin_inbox_move_task, id: @task.id, filter:)) do
              Button(type: "submit", small: true, aria: { label: t(".move", list:) }) { list }
            end
          end
        end
      end
    end
  end
end
