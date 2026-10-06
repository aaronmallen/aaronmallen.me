# frozen_string_literal: true

module Admin
  module UI
    module Components
      class FilterSwitch < Component
        prop :action, Blog::Types::String
        prop :name, Blog::Types::String
        prop :options, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::String)
        prop :selected, Blog::Types::String.optional
        prop :label, Blog::Types::String

        def view_template
          AutoForm(action: @action) do
            SegmentedControl(label: @label, name: @name, options:, selected: @selected)
          end
        end

        private

        def options = @options.transform_values { t(it) }
      end
    end
  end
end
