# frozen_string_literal: true

module Admin
  module UI
    module Components
      class MoreButton < Component
        prop :label, Blog::Types::String

        def view_template
          Button(
            small: true, variant: :gh, icon: "fa-solid fa-ellipsis", label: @label, aria: { haspopup: "menu" },
            data: { menu_more: true },
          )
        end
      end
    end
  end
end
