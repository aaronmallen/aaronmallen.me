# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Closed < Component
          AT = {
            Blog::Types::TaskStatus["canceled"] => ".canceled_at",
            Blog::Types::TaskStatus["done"] => ".done_at",
          }.freeze

          prop :task, Blog::Types::Instance(ROM::Struct)

          def view_template
            mark if @task.canceled?
            at unless @task.completed_at.nil?
          end

          private

          def at
            span(class: "task-finished") do
              Stamped(text: t(AT.fetch(@task.status), time: Stamped::MARK), at: @task.completed_at, format: :short)
            end
          end

          def mark
            Pill(color: :sand, icon: "fa-solid fa-ban") { t(".canceled") }
          end
        end
      end
    end
  end
end
