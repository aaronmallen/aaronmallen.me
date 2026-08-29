# frozen_string_literal: true

module Admin
  module UI
    module Components
      class SegmentedControl < Component
        prop :label, Blog::Types::String
        prop :name, Blog::Types::String
        prop :options, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::String)
        prop :selected, Blog::Types::String.optional

        def view_template
          div(class: "seg", role: "radiogroup", aria: { label: @label }) do
            @options.each { |value, text| render_option(value, text) }
          end
        end

        private

        def render_option(value, text)
          label(class: "seg-option") do
            input(class: "sr-only", type: "radio", name: @name, value:, checked: value == selected)
            span { text }
          end
        end

        def selected = @selected || @options.keys.first
      end
    end
  end
end
