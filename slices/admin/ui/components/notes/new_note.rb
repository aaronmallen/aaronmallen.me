# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class NewNote < Component
          prop :label, Blog::Types::String
          prop :folder_id, Blog::Types::Integer.optional, default: nil

          def view_template
            Form(action: path(:admin_create_note)) do
              HiddenFields(values: { folder_id: @folder_id })
              button(type: "submit", title: @label, aria: { label: @label }) { Icon("fa-regular fa-file") }
            end
          end
        end
      end
    end
  end
end
