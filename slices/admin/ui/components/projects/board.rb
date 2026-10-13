# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class Board < Component
          prop :published, Blog::Types::Bool

          def view_template
            Card(title: t(".heading")) do
              div(class: "form-stack") do
                Checkbox(switch: true, label: t(".publish"), name: "project[board_published]", checked: @published)
                Hint { t(".hint") }
              end
            end
          end
        end
      end
    end
  end
end
