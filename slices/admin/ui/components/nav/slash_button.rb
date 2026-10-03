# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class SlashButton < Component
          MARK = "/"

          def view_template
            label = t(".label")
            data = { palette_open: true, key: MARK, key_label: label }

            button(type: "button", class: "slash", aria: { label: }, data:) do
              span(aria: { hidden: "true" }) { MARK }
            end
          end
        end
      end
    end
  end
end
