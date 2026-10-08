# frozen_string_literal: true

module Admin
  module UI
    module Components
      class BulkToggle < Component
        prop :form, Blog::Types::String

        def view_template
          Button(
            icon: "fa-regular fa-square-check", hidden: true, aria: { pressed: "false" }, data: { bulk_toggle: @form },
          ) { t(".label") }
        end
      end
    end
  end
end
