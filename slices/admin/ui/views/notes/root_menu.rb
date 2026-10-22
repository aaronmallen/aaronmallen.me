# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Notes
        class RootMenu < View
          layout nil

          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label: t(".label"), return_to: @return_to) do |menu|
              menu.post(t(".new_note"), action: path(:admin_create_note), icon: "fa-regular fa-file", morph: false)
              menu.click(t(".new_folder"), target: "note-new-folder", icon: "fa-solid fa-folder-plus")
              menu.separator
              menu.click(t(".collapse_all"), target: "note-fold-all", icon: "fa-solid fa-chevron-up")
              menu.click(t(".expand_all"), target: "note-open-all", icon: "fa-solid fa-chevron-down")
            end
          end
        end
      end
    end
  end
end
