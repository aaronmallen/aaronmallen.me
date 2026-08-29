# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Posts
        class New < View
          include Components::Posts

          def initialize(**editor)
            super()
            @editor = editor
          end

          def view_template
            content_for(:title, t(".title"))

            Editor(**@editor)
          end
        end
      end
    end
  end
end
