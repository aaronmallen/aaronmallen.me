# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class Row < Component
          prop :note, Blog::Types::Instance(ROM::Struct)
          prop :current, Blog::Types::Integer.optional
          prop :icon, Blog::Types::String

          def view_template
            on = @note.id == @current

            a(
              class: ["nt-r", ("on" if on)], href: path(:admin_note, id: @note.id), aria: { current: ("page" if on) },
              data: { menu: path(:admin_note_menu, id: @note.id) },
            ) do
              Icon(@icon)
              span(class: "nt-t") { @note.title }
            end
          end
        end
      end
    end
  end
end
