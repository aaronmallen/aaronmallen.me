# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Confirm < Component
        def view_template
          template(data: { confirm_template: true }) do
            span(class: "confirm", role: "group", data: { confirm_ask: true }) do
              span(class: "confirm-message", data: { confirm_message: true })
              button(type: "button", class: "bt sm warn", data: { confirm_accept: true }) { t(".accept") }
              button(type: "button", class: "bt sm gh", data: { confirm_decline: true }) { t(".decline") }
            end
          end
        end
      end
    end
  end
end
