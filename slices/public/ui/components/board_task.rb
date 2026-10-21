# frozen_string_literal: true

module Public
  module UI
    module Components
      class BoardTask < Component
        KINDS = { card: "board", row: "board-row" }.freeze

        prop :task, Blog::Types::Instance(ROM::Struct)
        prop :href, Blog::Types::String
        prop :kind, Blog::Types::Symbol.enum(*KINDS.keys)

        def view_template
          li do
            a(class: @kind == :card ? "board-card" : "board-row", href: @href) do
              span(class: part("num")) { @task.label }
              span(class: part("title")) { @task.title }
              closed_on if @task.completed_at
            end
          end
        end

        private

        def closed_on
          span(class: part("meta")) do
            plain t([".closed", @task.status].join("."))
            whitespace
            Moment(at: @task.completed_at, format: :day)
          end
        end

        def part(name) = "#{KINDS.fetch(@kind)}-#{name}"
      end
    end
  end
end
