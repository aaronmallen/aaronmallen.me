# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Split < Component
        def view_template(&)
          div(class: "split", &)
        end
      end
    end
  end
end
