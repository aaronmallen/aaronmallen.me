# frozen_string_literal: true

require "rack/utils"

module Admin
  module UI
    module Components
      module Activity
        class Filters < Component
          CHECKED = Blog::Types::CHECKED
          TYPES = Structs::ActivityEvent::KINDS
          LABELS = TYPES.to_h { [it, ".types.#{it}"] }.freeze
          RANGES = Blog::Types::RangePreset.values
          UNCHECKED = "0"

          def self.query(from:, to:, types:, text:)
            {
              from: from.iso8601,
              to: to.iso8601,
              types: TYPES.to_h { [it, types.include?(it) ? CHECKED : UNCHECKED] },
              q: text,
            }
          end

          prop :counts, Blog::Types::Hash
          prop :from, Blog::Types::Date
          prop :types, Blog::Types::Array.of(Blog::Types::String)
          prop :text, Blog::Types::String
          prop :to, Blog::Types::Date
          prop :today, Blog::Types::Date
          prop :saved_views, Blog::Types::Hash

          def view_template
            div(class: "activity-rail") do
              Card do
                div(class: "form-stack") do
                  SavedViews(**@saved_views)
                  RangePresets(ranges: RANGES, today: @today, from: @from, to: @to) { it.href { preset_path(it) } }
                  filter_form
                end
              end
            end
          end

          private

          def filter_form
            AutoForm(action: path(:admin_activity)) do
              div(class: "form-stack") do
                DateRange(from: @from, to: @to, id_prefix: "activity")
                include_types
                text_field
              end
            end
          end

          def include_types
            Field(label: t(".include")) do
              div(class: "activity-types") { TYPES.each { type_choice(it) } }
            end
          end

          def preset_path(range)
            query = self.class.query(from: range.begin, to: range.end, types: @types, text: @text)

            "#{path(:admin_activity)}?#{Rack::Utils.build_nested_query(query)}"
          end

          def text_field
            Field(label: t(".contains"), id: "activity-q") do |control|
              Input(**control, type: "search", name: "q", value: @text, placeholder: t(".contains_placeholder"))
              Hint { t(".contains_hint") }
            end
          end

          def type_choice(name)
            type = Event::TYPES.fetch(name)

            div(class: "activity-type") do
              Icon(["fa-solid", type.icon, "activity-icon", type.color.to_s])
              Checkbox(label: t(LABELS.fetch(name)), name: "types[#{name}]", checked: @types.include?(name))
              span(class: "activity-type-count") { @counts.fetch(name, 0).to_s }
            end
          end
        end
      end
    end
  end
end
