# frozen_string_literal: true

require "rack/utils"

module Admin
  module UI
    module Components
      module Activity
        class Filters < Component
          CHECKED = Blog::Constants::CHECKED
          TYPES = Structs::ActivityEvent::KINDS
          LABELS = TYPES.to_h { [it, ".types.#{it}"] }.freeze
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
                  presets
                  filter_form
                end
              end
            end
          end

          private

          def dates
            Field(label: t(".from"), id: "activity-from") do |control|
              Input(**control, type: "date", name: "from", value: @from.iso8601, max: @to.iso8601)
            end
            Field(label: t(".to"), id: "activity-to") do |control|
              Input(**control, type: "date", name: "to", value: @to.iso8601, min: @from.iso8601)
            end
          end

          def filter_form
            AutoForm(action: path(:admin_activity)) do
              div(class: "form-stack") do
                dates
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

          def preset(days)
            current = preset_current?(days)

            a(class: ["seg-option", ("current" if current)], href: preset_path(days),
              aria: { current: ("true" if current) }) do
              t(".preset", count: days)
            end
          end

          def preset_current?(days) = @to == @today && @from == @today - (days - 1)

          def preset_path(days)
            query = self.class.query(from: @today - (days - 1), to: @today, types: @types, text: @text)

            "#{path(:admin_activity)}?#{Rack::Utils.build_nested_query(query)}"
          end

          def presets
            Field(label: t(".range")) do
              div(class: "seg", role: "group", aria: { label: t(".range") }) do
                Blog::Constants::ACTIVITY_RANGES.each { preset(it) }
              end
            end
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
              i(class: ["fa-solid", type.icon, "activity-icon", type.color.to_s], aria: { hidden: "true" })
              Checkbox(label: t(LABELS.fetch(name)), name: "types[#{name}]", checked: @types.include?(name))
              span(class: "activity-type-count") { @counts.fetch(name, 0).to_s }
            end
          end
        end
      end
    end
  end
end
