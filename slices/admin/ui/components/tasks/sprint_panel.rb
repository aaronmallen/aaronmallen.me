# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class SprintPanel < Component
          ORIGIN = Blog::Types::TaskOrigin["today"]
          TODAY = Blog::Types::TaskFilter["today"]

          prop :counts, Blog::Types::Hash
          prop :date, Blog::Types::Date
          prop :pool, Blog::Types::String
          prop(
            :pools,
            Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))),
          )
          prop :tasks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            Card(title: t(".title"), class: "sprint-panel", data: { key_list: true }) do |card|
              card.side { side }
              progress unless @tasks.empty?
              rows
              finished
              pull
            end
          end

          private

          def closed = @closed ||= @tasks.select(&:closed?)

          def finished
            return if closed.empty?

            details(class: "today-more") do
              summary do
                Icon("fa-solid fa-chevron-right today-more-chev")
                plain t(".finished", count: closed.size)
              end
              closed.each { row(it) }
            end
          end

          def open = @open ||= @tasks.reject(&:closed?)

          def progress
            aria = { label: t(".progress"), valuemin: 0, valuemax: @tasks.size, valuenow: closed.size }
            width = Blog::Helpers::Figures.share(closed.size, @tasks.size)

            div(class: "sprint-progress", role: "progressbar", aria:) do
              span(class: "sprint-progress-fill", style: "width: #{width}%")
            end
          end

          def pull
            details(class: "today-more", open: @tasks.empty?) do
              summary do
                Icon("fa-solid fa-chevron-right today-more-chev")
                plain t(".pull_from")
              end
              Pools(counts: @counts, origin: ORIGIN, pool: @pool, pools: @pools)
            end
          end

          def row(task)
            Row(task:, filter: TODAY, today: @date, origin: ORIGIN, scheduled: @date, large: !task.closed?)
          end

          def rows
            return Empty { t(@tasks.empty? ? ".empty" : ".clear", count: closed.size) } if open.empty?

            div(class: "sprint-rows") { open.each { row(it) } }
          end

          def side
            span(class: "sprint-note") { t(".done", done: closed.size, total: @tasks.size) } unless @tasks.empty?
            a(class: "today-link", href: path(:admin_tasks)) { t(".all_tasks") }
          end
        end
      end
    end
  end
end
