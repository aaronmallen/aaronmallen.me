# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Posts
        class Edit < View
          include Components::Posts

          def initialize(**editor)
            super()
            @editor = editor
          end

          def view_template
            content_for(:title, @editor[:post].title)

            Editor(**@editor)
          end
        end
      end
    end
  end
end
