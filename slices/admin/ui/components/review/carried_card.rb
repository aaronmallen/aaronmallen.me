# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class CarriedCard < Component
          prop :carried, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            Card(title: t(".title"), id: "review-carried") do
              next Empty { t(".empty") } if @carried.empty?

              @carried.each { ListItem(**item(it)) }
            end
          end

          private

          def item(task)
            {
              title: task.title,
              href: path(:admin_task, id: task.task_id),
              sub: t(".slipped", count: task.carried_count),
            }
          end
        end
      end
    end
  end
end
