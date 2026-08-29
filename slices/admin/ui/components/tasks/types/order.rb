# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        module Types
          class Order < Component
            CARETS = [
              [Blog::Types::TaskMove["up"], "fa-solid fa-caret-up", ".up"],
              [Blog::Types::TaskMove["down"], "fa-solid fa-caret-down", ".down"],
            ].freeze

            prop :type, Blog::Types::Instance(ROM::Struct)
            prop :first, Blog::Types::Bool, default: false
            prop :last, Blog::Types::Bool, default: false

            def view_template
              div(class: "task-order") { CARETS.each { caret(*it) } }
            end

            private

            def caret(direction, icon, label_key)
              label = t(label_key, type: @type.name)

              Form(action: path(:admin_reorder_task_type, id: @type.id, direction:)) do
                Button(type: "submit", disabled: held?(direction), class: "task-caret", aria: { label: }) do
                  i(class: icon, aria: { hidden: "true" })
                end
              end
            end

            def held?(direction) = direction == Blog::Types::TaskMove["up"] ? @first : @last
          end
        end
      end
    end
  end
end
