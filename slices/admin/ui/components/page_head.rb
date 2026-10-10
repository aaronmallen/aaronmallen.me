# frozen_string_literal: true

module Admin
  module UI
    module Components
      class PageHead < Blog::UI::Components::PageHead
        def tabs_side(&block)
          @tabs_side = block
          nil
        end

        def view_template(&)
          super
          Nav::ScreenTabs(&@tabs_side)
        end
      end
    end
  end
end
