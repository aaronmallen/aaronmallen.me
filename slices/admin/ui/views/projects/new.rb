# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Projects
        class New < View
          include Components::Projects

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
