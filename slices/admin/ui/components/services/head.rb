# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class Head < Component
          CLOSE_ICON = "fa-solid fa-xmark"

          prop :title, Blog::Types::String

          def view_template
            div(class: "svc-head") do
              h2(class: "card-title") { @title }
              Button(small: true, variant: :gh, icon: CLOSE_ICON, href: path(:admin_services), label: t(".close"))
            end
          end
        end
      end
    end
  end
end
