# frozen_string_literal: true

module Blog
  module UI
    module Components
      class Empty < Component
        def view_template(&)
          div(class: "empty", &)
        end
      end
    end
  end
end
