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
              RecordKey(kind: "task", label: @task.label)
              Status(status: @task.status)
              span(class: "read-meta-list") { place }
              SourceLink(source: @task.source)
              close
            end
          end

          private

          def close
            label = t(".close")

            OriginLink(
              origin: @origin, filter: @filter, variant: :gh, small: true, data: { task_close: true }, label:,
              icon: :close, class: "task-drawer-close",
            ) { label }
          end

          def place
            return l(@task.sprint.sprint_date, format: :short) if @task.ahead?(Blog::TimeZone.today)

            t(Helpers::TaskLists.name(@task.place))
          end
        end
      end
    end
  end
end
