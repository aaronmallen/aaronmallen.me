# frozen_string_literal: true

module Admin
  module UI
    module Views
      module People
        class Edit < View
          include Components::People

          def initialize(**editor)
            super()
            @editor = editor
          end

          def view_template = Editor(**@editor)
        end
      end
    end
  end
end
