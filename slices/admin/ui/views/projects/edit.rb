# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Projects
        class Edit < View
          include Components::Projects

          def initialize(**editor)
            super()
            @editor = editor
          end

          def view_template
            content_for(:title, @editor[:project].name)

            Editor(**@editor)
          end
        end
      end
    end
  end
end
