# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Toast < Component
        FLASH_KEY = "toast"

        prop :message, Blog::Types::String

        def view_template
          div(role: "status", data: { toast: true }) do
            div(class: "toast", hidden: true) do
              IconLabel(icon: "fa-solid fa-check toast-icon") { @message }
            end
          end
        end
      end
    end
  end
end
