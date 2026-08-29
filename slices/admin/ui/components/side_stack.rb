# frozen_string_literal: true

module Admin
  module UI
    module Components
      class SideStack < Component
        def view_template(&)
          div(class: "side-stack", &)
        end
      end
    end
  end
end
