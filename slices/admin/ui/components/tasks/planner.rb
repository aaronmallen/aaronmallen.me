# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Planner < Component
          FROM_TASKS = Blog::Types::TaskOrigin["tasks"]

          prop :counts, Blog::Types::Hash
          prop :date, Blog::Types::Date
          prop :pool, Blog::Types::String
          prop(
            :pools,
            Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))),
          )
          prop :origin, Blog::Types::String, default: FROM_TASKS

          def view_template
            div(class: "task-planner") do
              Card(label: t(".label", date: l(@date, format: :medium)), title: t(".ask")) do |card|
                card.side { span(class: "sprint-note") { t(".empty") } }
                p(class: "task-planner-note") { t(".note") }
                Pools(counts: @counts, origin: @origin, pool: @pool, pools: @pools)
              end
            end
          end
        end
      end
    end
  end
end
