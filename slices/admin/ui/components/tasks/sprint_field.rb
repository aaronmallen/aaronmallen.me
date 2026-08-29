# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class SprintField < Component
          prop :scope, Blog::Types::String
          prop :today, Blog::Types::Date
          prop :scheduled, Blog::Types::Date.optional, default: nil

          def view_template
            Field(label: t(".label"), id:) do
              Input(type: "date", id:, name: "task[sprint_on]", min: earliest.iso8601, value: @scheduled&.iso8601)
              Hint { t(hint) }
            end
          end

          private

          def earliest = [@today, @scheduled].compact.min

          def hint
            return ".unscheduled" if @scheduled.nil?
            return ".ran" if @scheduled < @today

            @scheduled == @today ? ".running" : ".waiting"
          end

          def id = FieldError.id_for(:sprint_on, @scope)
        end
      end
    end
  end
end
