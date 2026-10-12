# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class CarriedCard < Component
          prop :carried, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            Card(title: dotted(t(".title"), Blog::Helpers::Figures.count(@carried.size)), id: "review-carried") do
              next Empty { t(".empty") } if @carried.empty?

              Capped(items: @carried, more: path(:admin_tasks)) { row(it) }
            end
          end

          private

          def row(task)
            data = { menu: path(:admin_task_menu, id: task.task_id) }

            ListItem(title: task.title, href: path(:admin_task, id: task.task_id), data:) do
              span(class: "review-slipped") { t(".slipped", count: task.carried_count) }
            end
          end
        end
      end
    end
  end
end
