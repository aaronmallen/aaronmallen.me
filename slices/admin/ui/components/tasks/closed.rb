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
            local = Blog::TimeZone.local(@task.completed_at)

            span(class: "task-finished") do
              t(AT.fetch(@task.status), date: l(local.to_date, format: :short), time: l(local, format: :clock))
            end
          end

          def mark
            Pill(color: :sand) do
              IconLabel(icon: "fa-solid fa-ban") { t(".canceled") }
            end
          end
        end
      end
    end
  end
end
