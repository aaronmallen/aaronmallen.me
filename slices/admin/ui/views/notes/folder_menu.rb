# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Notes
        class FolderMenu < View
          include Components::Notes

          layout nil

          prop :folder, Blog::Types::Instance(Structs::NoteTree)
          prop :tree, Blog::Types::Instance(Structs::NoteTree)
          prop :shut, Blog::Types::Bool
          prop :links, Blog::Types::Integer
          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label: @folder.path, return_to: @return_to) do |menu|
              fold(menu)
              menu.separator
              adds(menu)
              menu.separator
              changes(menu)
              menu.copy(t(".copy_path"), text: @folder.path, copied: t(".copied_path"), icon: :copy)
              menu.separator
              remove(menu)
            end
          end

          private

          def act(route) = path(route, id: @folder.id)

          def adds(menu)
            menu.post(t(".new_note"), action: path(:admin_create_note), icon: "fa-regular fa-file", morph: false,
                                      fields: { folder_id: @folder.id })
            menu.sub(t(".new_subfolder"), icon: "fa-solid fa-folder-plus") do
              menu.field(t(".folder_name"), action: path(:admin_create_note_folder), name: "path", pattern: ".*\\S.*",
                                            invalid: t(".blank"), suggest: [], fields: { prefix: "#{@folder.path}/" })
            end
          end

          def changes(menu)
            menu.sub(t(".rename"), icon: "fa-solid fa-i-cursor") do
              menu.field(
                @folder.name, action: act(:admin_rename_note_folder), name: "name", pattern: ".*\\S.*",
                              invalid: t(".blank"), suggest: [],
              )
            end
            parent = @folder.path.rpartition("/").first
            MoveTo(menu:, tree: @tree, current: parent, action: act(:admin_move_note_folder), skip: @folder.path)
            hint = @links.to_s unless @links.zero?
            menu.link(t(".linked"), href: act(:admin_note_folder), icon: "fa-solid fa-link", hint:)
          end

          def fold(menu)
            menu.link(t(".open"), href: act(:admin_note_folder), icon: "fa-regular fa-folder-open")
            target = "note-folder-#{@folder.id}"
            return menu.click(t(".expand"), target:, icon: "fa-solid fa-chevron-down") if @shut

            menu.click(t(".collapse"), target:, icon: "fa-solid fa-chevron-up")
          end

          def remove(menu)
            count = @folder.count
            confirm = @folder.empty? ? nil : t(".confirm_remove", count:)

            menu.post(t(".remove"), action: act(:admin_remove_note_folder), icon: :trash, warn: true, confirm:)
          end
        end
      end
    end
  end
end
