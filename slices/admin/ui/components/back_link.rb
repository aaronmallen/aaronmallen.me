# frozen_string_literal: true

module Admin
  module UI
    module Components
      class BackLink < Component
        ICON = "fa-solid fa-arrow-left"

        prop :href, Blog::Types::String
        prop :attributes, Blog::Types::Hash, :**

        def view_template(&) = Button(href: @href, icon: ICON, **@attributes, &)
      end
    end
  end
end
