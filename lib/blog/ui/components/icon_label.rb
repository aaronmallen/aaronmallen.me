# frozen_string_literal: true

module Blog
  module UI
    module Components
      class IconLabel < Component
        prop :icon, Icon::NAME

        def view_template(&)
          Icon(@icon)
          span(&)
        end
      end
    end
  end
end
