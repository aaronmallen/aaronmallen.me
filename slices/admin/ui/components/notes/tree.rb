# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class Tree < Component
          prop :tree, Blog::Types::Instance(Structs::NoteTree)
          prop :pinned, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :current, Blog::Types::Integer.optional

          def view_template
            aside(class: "nt-side", aria: { label: t(".label") },
                  data: { menu: path(:admin_notes_menu), note_tree: "" }) do
              pins
              files
              new_folder
              div(class: "nt-tree") { Branch(folder: @tree, current: @current) }
              button(type: "button", id: "note-fold-all", hidden: true, data: { note_fold: "shut" })
              button(type: "button", id: "note-open-all", hidden: true, data: { note_fold: "open" })
            end
          end

          private

          def files
            div(class: "nt-gh") do
              p(class: "nt-g") { t(".files") }
              span(class: "nt-da on") do
                NewNote(label: t(".new_note"))
                NewFolder(label: t(".new_folder"), id: "note-new-folder")
              end
            end
          end

          def new_folder
            form = { class: "nt-nd", hidden: true, data: { note_folder_form: "" } }

            Form(action: path(:admin_create_note_folder), **form) do
              Icon("fa-solid fa-folder-plus")
              input(
                type: "text", name: "path", autocomplete: "off", aria: { label: t(".folder_path") },
                placeholder: t(".folder_placeholder"),
              )
            end
          end

          def pins
            return if @pinned.empty?

            p(class: "nt-g") { t(".pinned") }
            @pinned.each { Row(note: it, current: @current, icon: "fa-solid fa-thumbtack") }
          end
        end
      end
    end
  end
end
