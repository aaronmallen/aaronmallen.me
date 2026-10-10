# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Closed < Component
          AT = Blog::Types::ClosedTaskStatus.values.to_h { [it, ".#{it}_at"] }.freeze

          prop :task, Blog::Types::Instance(ROM::Struct)

          def view_template
            mark if @task.canceled? && @task.completed_at.nil?
            at unless @task.completed_at.nil?
          end

          private

          def at
            span(class: "task-finished") do
              Stamped(text: t(AT.fetch(@task.status), time: Stamped::MARK), at: @task.completed_at, format: :short)
            end
          end

          def mark
            span(class: "task-mark sand") do
              Icon("fa-solid fa-ban")
              plain t(".canceled")
            end
          end
        end
      end
    end
  end
end
