# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class WorkedFields < Component
          CONTRACT = ::Tasks::Contracts::WorkedContract
          PARTS = { hours: [".hours", CONTRACT::HOURS.max], minutes: [".minutes", CONTRACT::MINUTES.max] }.freeze

          prop :name, Blog::Types::String
          prop :scope, Blog::Types::String
          prop :seconds, Blog::Types::Integer
          prop :values, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }
          prop :errors, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }

          def view_template
            div(class: "task-worked-fields") do
              CONTRACT.fields(@seconds).each { |field, shown| part(field, shown) }
            end
          end

          private

          def part(field, shown)
            label, max = PARTS.fetch(field)
            value = @values.key?(field) ? @values[field] : shown

            Field(label: t(label), name: field, errors: @errors, error: FieldError, scope: @scope) do |control|
              Input(**control, min: 0, max:, step: 1, type: "number", name: "#{@name}[#{field}]", value: value.to_s)
            end
          end
        end
      end
    end
  end
end
