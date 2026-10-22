# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class Branch < Component
          prop :folder, Blog::Types::Instance(Structs::NoteTree)
          prop :current, Blog::Types::Integer.optional

          def view_template
            @folder.folders.each { folder(it) }
            @folder.notes.each { Row(note: it, current: @current, icon: "fa-regular fa-file-lines") }
          end

          private

          def actions(folder)
            span(class: "nt-da hov") do
              NewNote(label: t(".new_note", path: folder.path), folder_id: folder.id)
              NewFolder(label: t(".new_folder", path: folder.path), path: "#{folder.path}/")
              remove(folder) if folder.empty?
            end
          end

          def folder(folder)
            details(class: "nt-dir", open: true, data: { note_folder: folder.id }) do
              summary(class: "nt-dr", id: "note-folder-#{folder.id}",
                      data: { menu: path(:admin_note_folder_menu, id: folder.id) }) { row(folder) }
              actions(folder)
              div(class: "nt-kids") do
                p(class: "nt-emp") { t(".empty") } if folder.empty?
                Branch(folder:, current: @current)
              end
            end
          end

          def remove(folder)
            label = t(".remove", path: folder.path)

            Form(action: path(:admin_remove_note_folder, id: folder.id)) do
              button(type: "submit", title: label, aria: { label: }) { Icon("fa-solid fa-xmark") }
            end
          end

          def row(folder)
            Icon("fa-solid fa-chevron-down nt-cv")
            Icon("fa-regular fa-folder-open nt-fo")
            Icon("fa-regular fa-folder nt-fc")
            span(class: "nt-t") { folder.name }
            held = folder.count
            span(class: "nt-n") { count(held) } unless held.zero?
          end
        end
      end
    end
  end
end
