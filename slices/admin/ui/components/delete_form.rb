# frozen_string_literal: true

module Admin
  module UI
    module Components
      class DeleteForm < Component
        prop :attributes, Blog::Types::Hash, :**

        def view_template(&) = ButtonForm(variant: :warn, icon: :trash, **@attributes, &)
      end
    end
  end
end
