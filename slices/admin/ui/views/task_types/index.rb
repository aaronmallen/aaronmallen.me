# frozen_string_literal: true

module Admin
  module UI
    module Views
      module TaskTypes
        class Index < View
          include Components::Tasks::Types

          def initialize(counts:, editing:, errors:, types:, values:)
            super()
            @counts = counts
            @editing = editing
            @errors = errors
            @types = types
            @values = values
          end

          def view_template
            PageHead(title: t(".heading"), sub: t(".count", count: @types.size)) { back }

            Card(label: t(".label"), title: t(".title")) do
              IconList()
              Capture(values: @values, errors: @errors)
              rows
            end

            Hint { t(".note") }
          end

          private

          def back
            a(class: "btn", href: path(:admin_tasks)) do
              i(class: "fa-solid fa-arrow-left", aria: { hidden: "true" })
              span { t(".back") }
            end
          end

          def rows
            return Empty { t(".empty") } if @types.empty?

            last = @types.size - 1
            @types.each_with_index do |type, index|
              Row(
                type:, count: @counts.fetch(type.id, 0), editing: @editing,
                first: index.zero?, last: index == last,
              )
            end
          end
        end
      end
    end
  end
end
