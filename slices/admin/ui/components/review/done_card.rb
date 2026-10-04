# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class DoneCard < Component
          prop :done, Blog::Types::Hash.map(Blog::Types::Date, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct)))

          def view_template
            Card(title: t(".title"), id: "review-done") do
              next Empty { t(".empty") } if @done.empty?

              @done.each { |day, tasks| day_group(day, tasks) }
            end
          end

          private

          def day_group(day, tasks)
            section(class: "review-group") do
              h3(class: "review-group-title") { l(day, format: :weekday) }
              tasks.each { ListItem(**item(it)) }
            end
          end

          def item(task)
            { title: task.title, href: path(:admin_task, id: task.task_id), sub: Blog::Figures.hours(task.worked_seconds) }
          end
        end
      end
    end
  end
end
