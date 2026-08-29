# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class Move < Component
          CARETS = [
            [Blog::Types::ProjectMove["up"], "fa-solid fa-caret-up", ".up"],
            [Blog::Types::ProjectMove["down"], "fa-solid fa-caret-down", ".down"],
          ].freeze

          prop :project, Blog::Types::Instance(ROM::Struct)
          prop :first, Blog::Types::Bool, default: false
          prop :last, Blog::Types::Bool, default: false

          def view_template
            div(class: "proj-move") { CARETS.each { caret(*it) } }
          end

          private

          def caret(direction, icon, label_key)
            label = t(label_key, project: @project.name)

            Form(action: path(:admin_move_project, id: @project.id, direction:)) do
              Button(type: "submit", disabled: held?(direction), class: "proj-caret", aria: { label: }) do
                i(class: icon, aria: { hidden: "true" })
              end
            end
          end

          def held?(direction) = direction == Blog::Types::ProjectMove["up"] ? @first : @last
        end
      end
    end
  end
end
