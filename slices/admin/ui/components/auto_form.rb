# frozen_string_literal: true

module Admin
  module UI
    module Components
      class AutoForm < Component
        HOOK = { autosubmit: "" }.freeze

        prop :method, Blog::Types::String, default: Blog::UI::Components::Form::GET
        prop :data, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
        prop :attributes, Blog::Types::Hash, :**

        def view_template
          Form(method: @method, **@attributes, data: { **@data, **HOOK }) { yield if block_given? }
        end
      end
    end
  end
end
