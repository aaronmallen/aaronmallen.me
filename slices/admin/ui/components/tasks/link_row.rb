# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class LinkRow < Component
          PLACES = {
            Blog::Types::TaskStatus["canceled"] => "ui.components.tasks.link_row.places.canceled",
            Blog::Types::TaskStatus["done"] => "ui.components.tasks.link_row.places.done",
            Blog::Types::TaskStatus["in_progress"] => "ui.components.tasks.link_row.places.in_progress",
          }.freeze
          TODAY = Blog::Types::TaskFilter["today"]

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :link, Blog::Types::Instance(Data)
          prop :tab, Blog::Types::String
          prop :origin, Blog::Types::String

          def self.place_key(task) = PLACES.fetch(task.status) { Helpers::TaskLists.name(task.list || TODAY) }

          def view_template
            div(class: "task-link-row") do
              span(class: "task-link-label") { t(Links.label_key(@link)) }
              RecordKey(kind: "task", id: other.id)
              link_title
              span(class: "task-link-place") { t(self.class.place_key(other)) }
              unlink_form
            end
          end

          private

          def link_title
            href = path(:admin_task, id: other.id, filter: @tab, origin: @origin)
            a(class: "task-link-title", href:, data: { task_open: true }) { other.title }
          end

          def other = @link.task

          def unlink_form
            label = t(".remove", key: RecordKey.key(other.id))

            Form(action: path(:admin_unlink_task, id: @task.id, other_id: other.id)) do
              HiddenFields(values: { filter: @tab, origin: @origin })
              Button(
                type: "submit", variant: :gh, small: true, label:, icon: "fa-solid fa-xmark",
              )
            end
          end
        end
      end
    end
  end
end
