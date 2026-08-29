# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class TypeTag < Component
          prop :type, Blog::Types::Instance(ROM::Struct).optional, default: nil

          def view_template
            return Pill(color: nil) { t(".untyped") } unless @type

            Pill(color: Blog::UI::Components::Pill.for_tag_color(@type.color)) do
              i(class: "fa-solid fa-#{@type.icon}", aria: { hidden: "true" }) if @type.icon
              span { @type.name }
            end
          end
        end
      end
    end
  end
end
