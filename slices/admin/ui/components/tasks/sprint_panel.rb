# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class SprintPanel < Component
          ORIGIN = Blog::Types::TaskOrigin["today"]
          TODAY = Blog::Types::TaskFilter["today"]

          prop :date, Blog::Types::Date
          prop :pool, Blog::Types::String
          prop(
            :pools,
            Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))),
          )
          prop :tasks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            div(class: "sprint-panel") { @tasks.empty? ? planner : panel }
          end

          private

          def capture
            Capture(
              filter: TODAY, values: Dry::Core::Constants::EMPTY_HASH,
              errors: Dry::Core::Constants::EMPTY_HASH, autofocus: false, origin: ORIGIN, scope: "sprint",
              target: t(".target"),
            )
          end

          def done = @tasks.count(&:closed?)

          def foot
            div(class: "sprint-foot") do
              capture
              a(class: "btn gh", href: path(:admin_tasks)) do
                i(class: "fa-solid fa-list-check", aria: { hidden: "true" })
                span { t(open.empty? ? ".pull" : ".all_tasks") }
              end
            end
          end

          def label = t(".label", date: l(@date, format: :short))

          def open = @open ||= @tasks.reject(&:closed?)

          def panel
            Card(label:, title: t(open.empty? ? ".clear" : ".title")) do |card|
              card.side { span(class: "sprint-note") { t(".done", done:, total: @tasks.size) } }
              progress
              rows
              foot
            end
          end

          def planner
            Planner(date: @date, origin: ORIGIN, pool: @pool, pools: @pools)
          end

          def progress
            span(class: "sprint-progress") do
              span(class: "sprint-progress-fill", style: "width: #{Blog::Figures.share(done, @tasks.size)}%")
            end
          end

          def row(task)
            Row(task:, filter: TODAY, today: @date, origin: ORIGIN, scheduled: @date)
          end

          def rows
            return Empty { t(".finished", count: done) } if open.empty?

            open.each { row(it) }
          end
        end
      end
    end
  end
end
