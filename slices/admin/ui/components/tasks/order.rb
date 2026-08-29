# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Order < Component
          CARETS = [
            [Blog::Types::TaskMove["up"], "fa-solid fa-caret-up", ".up"],
            [Blog::Types::TaskMove["down"], "fa-solid fa-caret-down", ".down"],
          ].freeze

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::String
          prop :first, Blog::Types::Bool, default: false
          prop :origin, Blog::Types::String, default: Blog::Types::TaskOrigin["tasks"]
          prop :last, Blog::Types::Bool, default: false

          def view_template
            div(class: "task-order") { CARETS.each { caret(*it) } }
          end

          private

          def caret(direction, icon, label_key)
            label = t(label_key, task: @task.title)

            Form(action: path(:admin_reorder_task, id: @task.id, direction:)) do
              input(type: "hidden", name: "filter", value: @filter)
              input(type: "hidden", name: "origin", value: @origin)
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
