# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class CadenceFields < Component
          KINDS = Blog::Types::TaskCadence.values.freeze
          MONTHS = Date::MONTHNAMES.drop(1).each.with_index(1).to_h { |name, number| [number.to_s, name] }.freeze
          WEEKDAYS = Date::DAYNAMES.each.with_index.to_h { |name, number| [number.to_s, name] }.freeze
          WEEKS = %w[1 2 3 4 -1].freeze

          prop :scope, Blog::Types::String
          prop :today, Blog::Types::Date
          prop :values, Blog::Types::Fields, default: Blog::Constants::EMPTY_HASH
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def view_template
            div(class: "task-form-pair", data: { cadence: "" }) do
              kind_field
              every_field
              week_field
              weekday_field
              month_field
              day_field
              starts_on_field
            end
          end

          private

          def day_field
            part(:day, %w[month_day yearly]) do |control|
              Input(**control, type: "number", name: name(:day), min: 1, max: 31, value: value(:day, @today.day))
            end
          end

          def every_field
            label = -> { %w[days weeks].each { unit(it) } }

            part(:every, %w[days weeks], label:) do |control|
              Input(**control, type: "number", name: name(:every), min: 1, max: 365, value: value(:every, 1))
            end
          end

          def kind = value(:cadence, "")

          def kind_field
            Field(label: t(".cadence"), name: :cadence, errors: @errors, error: FieldError, scope: @scope) do |control|
              Select(**control, name: name(:cadence), options: kinds, selected: kind, data: { cadence_kind: "" })
            end
          end

          def kinds = { "" => t(".never"), **KINDS.to_h { [it, t([".kinds", it].join("."))] } }

          def month_field
            part(:month, %w[yearly]) do |control|
              Select(**control, name: name(:month), options: MONTHS, selected: value(:month, @today.month))
            end
          end

          def name(field) = "task[recur][#{field}]"

          def part(field, kinds, label: t(["", field].join(".")))
            off = !kinds.include?(kind)

            Field(
              label:, name: field, errors: @errors, error: FieldError, scope: @scope,
              hidden: off, data: { cadence_for: kinds.join(" ") },
            ) { yield it.merge(disabled: off) }
          end

          def starts_on_field
            part(:starts_on, %w[weeks]) do |control|
              Input(**control, type: "date", name: name(:starts_on), value: value(:starts_on, @today.iso8601))
              Hint { t(".starts_on_hint") }
            end
          end

          def unit(kind)
            span(hidden: kind != self.kind, data: { cadence_for: kind }) { t([".every", kind].join(".")) }
          end

          def value(field, fallback)
            stored = @values[field].to_s

            stored.empty? ? fallback.to_s : stored
          end

          def week_field
            part(:week, %w[month_weekday]) do |control|
              Select(**control, name: name(:week), options: weeks, selected: value(:week, WEEKS.first))
            end
          end

          def weekday_field
            part(:weekday, %w[weeks month_weekday]) do |control|
              Select(**control, name: name(:weekday), options: WEEKDAYS, selected: value(:weekday, @today.wday))
            end
          end

          def weeks = WEEKS.to_h { [it, t([".weeks", it].join("."))] }
        end
      end
    end
  end
end
