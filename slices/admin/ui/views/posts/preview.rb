# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Posts
        class Preview < View
          include Components::Posts

          layout nil

          prop :preview, Blog::Types::Hash, :**

          def view_template
            Preview(**@preview)
          end
        end
      end
    end
  end
end
