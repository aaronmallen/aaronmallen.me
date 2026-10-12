# frozen_string_literal: true

module Admin
  module UI
    module Components
      class AutoForm < Component
        HOOK = { autosubmit: "" }.freeze

        prop :attributes, Blog::Types::Hash, :**

        def view_template
          Form(method: Blog::UI::Components::Form::GET, **@attributes, data: HOOK) { yield if block_given? }
        end
      end
    end
  end
end
