# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class SlashButton < Component
          MARK = "/"

          def view_template
            button(type: "button", class: "slash", aria: { label: t(".label") }, data: { palette_open: true }) do
              span(aria: { hidden: "true" }) { MARK }
            end
          end
        end
      end
    end
  end
end
