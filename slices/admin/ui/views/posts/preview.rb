# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Posts
        class Preview < View
          include Components::Posts

          layout nil

          def initialize(**preview)
            super()
            @preview = preview
          end

          def view_template
            Preview(**@preview)
          end
        end
      end
    end
  end
end
