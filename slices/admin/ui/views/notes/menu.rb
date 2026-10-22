# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Notes
        class Menu < View
          include Components::Notes

          layout nil

          prop :note, Blog::Types::Instance(ROM::Struct)
          prop :tree, Blog::Types::Instance(Structs::NoteTree)
          prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label: @note.title, return_to: @return_to) do |menu|
              opens(menu)
              menu.separator
              changes(menu)
              menu.separator
              copies(menu)
              menu.separator
              menu.post(t(".delete"), action: act(:admin_delete_note), icon: :trash, warn: true, confirm: :forever)
            end
          end

          private

          def act(route) = path(route, id: @note.id)

          def changes(menu)
            menu.sub(t(".rename"), icon: "fa-solid fa-i-cursor") do
              menu.field(@note.title, action: act(:admin_rename_note), name: "title", pattern: ".*\\S.*",
                                      invalid: t(".blank"), suggest: [])
            end
            MoveTo(menu:, tree: @tree, current: @tree.path_of(@note.folder_id), action: act(:admin_move_note))
            MenuTags(
              menu:, tags: @tags, names: @note.tags.map(&:name), tag_path: act(:admin_tag_note),
              untag_path: act(:admin_untag_note),
            )
          end

          def copies(menu)
            text = "[[#{@note.title}]]"

            menu.copy(t(".copy_link"), text:, copied: t(".copied_link"), icon: :copy, hint: "[[…]]")
            menu.post(t(".duplicate"), action: act(:admin_duplicate_note), icon: "fa-regular fa-clone", morph: false)
            menu.post(t(".new_beside"), action: path(:admin_create_note), icon: "fa-regular fa-file", morph: false,
                                        fields: { folder_id: @note.folder_id })
          end

          def opens(menu)
            menu.link(t(".open"), href: act(:admin_note), icon: "fa-regular fa-file-lines")
            menu.link(t(".edit"), href: path(:admin_note, id: @note.id, edit: 1), icon: :edit)
            pin(menu)
          end

          def pin(menu)
            pinned = @note.pinned
            fields = { pinned: (Blog::Constants::CHECKED unless pinned) }

            menu.post(pinned ? t(".unpin") : t(".pin"), action: act(:admin_pin_note), icon: "fa-solid fa-thumbtack",
                                                        fields:)
          end
        end
      end
    end
  end
end
