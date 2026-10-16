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
        prop :keep, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

        def view_template
          AutoForm(action: @action) do
            HiddenFields(values: @keep)
            SegmentedControl(label: @label, name: @name, options: @options, selected: @selected)
          end
        end
      end
    end
  end
end
