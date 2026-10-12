# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class SendButton < Component
          def view_template
            Button(type: "submit", variant: :pri, small: true, icon: "fa-solid fa-paper-plane") do
              plain t(".send")
              kbd(class: "kbd") { t(".key") }
            end
          end
        end
      end
    end
  end
end
