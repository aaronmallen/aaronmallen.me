# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class IssueItem < Component
          LISTS = (Blog::Types::TaskFilter.values - [Blog::Types::TaskFilter["external"]]).freeze
          ORIGIN = Blog::Types::TaskOrigin["inbox"]

          prop :task, Blog::Types::Instance(ROM::Struct)

          def view_template
            Row(id: "issue-#{@task.id}", kind: :task, title: @task.title,
                href: path(:admin_task, id: @task.id)) do |row|
              row.meta { meta }
              actions
            end
          end

          private

          def actions
            LISTS.each { move(it) unless it == @task.place }
            edit
            Form(action: path(:admin_inbox_see_task, id: @task.id)) do
              Button(type: "submit", variant: :gh, small: true) { t(".seen") }
            end
            Inbox::Snooze(kind: "task", id: @task.id)
          end

          def edit
            href = path(:admin_edit_task, id: @task.id, origin: ORIGIN)

            Button(href:, data: { task_open_edit: true }, small: true) { t(".edit") }
          end

          def meta
            Moment(at: @task.created_at)
            Tasks::SourceLink(source: @task.source)
            @task.tags.each { Tag(tag: it) }
          end

          def move(filter)
            list = t(Helpers::TaskLists.title(filter))

            Form(action: path(:admin_inbox_move_task, id: @task.id, filter:)) do
              Button(type: "submit", small: true, aria: { label: t(".move", list:) }) { list }
            end
          end
        end
      end
    end
  end
end
