# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class NewFolder < Component
          prop :label, Blog::Types::String
          prop :path, Blog::Types::String, default: Blog::Constants::EMPTY_STRING
          prop :id, Blog::Types::String.optional, default: nil

          def view_template
            button(type: "button", id: @id, title: @label, aria: { label: @label }, data: { note_new_folder: @path }) do
              Icon("fa-solid fa-folder-plus")
            end
          end
        end
      end
    end
  end
end
