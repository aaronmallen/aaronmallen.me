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
                href: path(:admin_task, id: @task.id), menu:) do |row|
              row.meta { meta }
              actions
            end
          end

          private

          def actions
            LISTS.each { move(it) unless it == @task.place }
            edit
            ButtonForm(action: path(:admin_inbox_see_task, id: @task.id), label: t(".seen"), variant: :gh, morph: true)
            Inbox::Snooze(kind: "task", id: @task.id)
          end

          def edit
            href = path(:admin_edit_task, id: @task.id, origin: ORIGIN)

            Button(href:, data: { task_open_edit: true }, small: true) { t(".edit") }
          end

          def menu = path(:admin_task_menu, id: @task.id, origin: ORIGIN)

          def meta
            Moment(at: @task.created_at)
            Tasks::SourceLink(source: @task.source)
            @task.tags.each { Tag(tag: it, project_key: @task.project_key_for(it)) }
          end

          def move(filter)
            list = t(Helpers::TaskLists.title(filter))

            ButtonForm(
              action: path(:admin_inbox_move_task, id: @task.id, filter:), label: list, morph: true,
              button: { aria: { label: t(".move", list:) } },
            )
          end
        end
      end
    end
  end
end
