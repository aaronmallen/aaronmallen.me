# frozen_string_literal: true

require "rack/utils"

module Admin
  module UI
    module Components
      module Activity
        class Filters < Component
          CHECKED = Blog::Constants::CHECKED
          HINT_ID = "activity-q-hint"
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
            div(class: "activity-bar") do
              RangePresets(ranges: RANGES, today: @today, from: @from, to: @to) { it.href { preset_path(it) } }
              filter_form
              SavedViews(**@saved_views)
            end
          end

          private

          def chosen?(name) = @types.include?(name)

          def filter_form
            AutoForm(action: path(:admin_activity), class: "activity-filter") do
              DateRange(from: @from, to: @to, id_prefix: "activity")
              text_field
              include_types
              Hint(id: HINT_ID, class: "activity-hint") { t(".contains_hint") }
            end
          end

          def include_types
            div(class: "activity-types", role: "group", aria: { label: t(".include") }) do
              TYPES.each { type_choice(it) }
            end
          end

          def preset_path(range)
            query = self.class.query(from: range.begin, to: range.end, types: @types, text: @text)

            "#{path(:admin_activity)}?#{Rack::Utils.build_nested_query(query)}"
          end

          def search_attributes
            { type: "search", name: "q", value: @text, placeholder: t(".contains_placeholder"),
              aria: { describedby: HINT_ID } }
          end

          def text_field
            Field(label: t(".contains"), id: "activity-q") { |control| Input(**control, **search_attributes) }
          end

          def type_choice(name)
            type = Event::TYPES.fetch(name)

            label(class: "activity-type") do
              input(type: "hidden", name: "types[#{name}]", value: UNCHECKED)
              input(class: "sr-only", type: "checkbox", name: "types[#{name}]", value: CHECKED, checked: chosen?(name))
              Icon(["fa-solid", type.icon, "activity-icon", type.color.to_s])
              span { t(LABELS.fetch(name)) }
              whitespace
              span(class: "activity-type-count") { @counts.fetch(name, 0).to_s }
            end
          end
        end
      end
    end
  end
end
