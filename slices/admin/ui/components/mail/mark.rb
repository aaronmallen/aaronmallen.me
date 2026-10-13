# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class Mark < Component
          prop :icon, Blog::UI::Components::Icon::NAME
          prop :text, Blog::Types::String
          prop :tone, Blog::Types::String.optional, default: nil

          def view_template
            span(class: ["mail-mark", @tone]) do
              Icon(@icon)
              plain @text
            end
          end
        end
      end
    end
  end
end
