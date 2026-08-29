# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        module Types
          class Row < Component
            prop :type, Blog::Types::Instance(ROM::Struct)
            prop :count, Blog::Types::Integer
            prop :editing, Blog::Types::Hash.optional, default: nil
            prop :first, Blog::Types::Bool, default: false
            prop :last, Blog::Types::Bool, default: false

            def view_template
              div(class: "li") do
                main
                side
              end
            end

            private

            def color_form
              Form(action: path(:admin_update_task_type, id: @type.id)) do
                input(type: "hidden", name: "type[name]", value: @type.name)
                Swatches(name: "type[color]", scope:, selected: @type.color, submit: true)
              end
            end

            def editing? = @editing&.fetch(:id) == @type.id

            def errors = editing? ? @editing[:errors] : Dry::Core::Constants::EMPTY_HASH

            def held? = @count.positive?

            def icon = (@editing[:icon] if editing?) || @type.icon

            def icon_form
              Form(action: path(:admin_update_task_type, id: @type.id), class: "task-capture-row") do
                input(type: "hidden", name: "type[name]", value: @type.name)
                label(class: "sr-only", for: Tasks::FieldError.id_for(:icon, scope)) { t(".icon") }
                Input(
                  **Tasks::FieldError.control_attributes(:icon, errors, scope),
                  autocomplete: "off", list: IconList::ID, name: "type[icon]", placeholder: t(".icon_placeholder"),
                  value: icon,
                )
                Button(type: "submit", small: true) { t(".save") }
              end
            end

            def main
              div(class: "li-main") do
                rename_form
                Tasks::FieldError(field: :name, errors:, scope:)
                icon_form
                Tasks::FieldError(field: :icon, errors:, scope:)
                meta
              end
            end

            def meta
              p(class: "task-meta") do
                Tasks::TypeTag(type: @type)
                Pill(color: :blue) { t(".tasks", count: @count) } if held?
              end
            end

            def name = editing? ? @editing[:name] : @type.name

            def remove
              Form(**remove_attributes) do
                Button(variant: :warn, type: "submit", small: true, disabled: held?) { t(".remove") }
              end
            end

            def remove_attributes
              {
                action: path(:admin_delete_task_type, id: @type.id),
                data: { confirm: t(".confirm_remove", type: @type.name) },
                title: held? ? t(".held", count: @count) : nil,
              }
            end

            def rename_form
              Form(action: path(:admin_update_task_type, id: @type.id), class: "task-capture-row") do
                label(class: "sr-only", for: Tasks::FieldError.id_for(:name, scope)) { t(".name") }
                Input(**Tasks::FieldError.control_attributes(:name, errors, scope), name: "type[name]", value: name)
                Button(type: "submit", small: true) { t(".save") }
              end
            end

            def scope = "type-#{@type.id}"

            def side
              div(class: "li-side") do
                color_form
                Order(type: @type, first: @first, last: @last)
                remove
              end
            end
          end
        end
      end
    end
  end
end
