# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class DrawerHead < Component
          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::String
          prop :origin, Blog::Types::TaskOrigin

          def view_template
            header(class: "task-drawer-head") do
              RecordKey(kind: "task", id: @task.id)
              Status(status: @task.status)
              span(class: "read-meta-list") { t(Helpers::TaskLists.name(@task.place)) }
              SourceLink(source: @task.source)
              close
            end
          end

          private

          def close
            label = t(".close")

            OriginLink(
              origin: @origin, filter: @filter, variant: :gh, small: true, data: { task_close: true }, label:,
              icon: "fa-solid fa-xmark", class: "task-drawer-close",
            ) { label }
          end
        end
      end
    end
  end
end
