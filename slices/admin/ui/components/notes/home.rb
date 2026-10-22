# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class Home < Component
          prop :notes, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :tree, Blog::Types::Instance(Structs::NoteTree)

          def view_template
            div(class: "stack") do
              Card(title: t(".recent"), empty: (t(".empty") if @notes.empty?)) { @notes.each { row(it) } }
            end
          end

          private

          def folder(note)
            folder_path = @tree.path_of(note.folder_id)
            folder_path.empty? ? "/" : folder_path
          end

          def row(note)
            div(class: "nt-rw", data: { key_row: true, menu: path(:admin_note_menu, id: note.id) }) do
              a(class: "nt-rt", href: path(:admin_note, id: note.id), data: { key_open: true }) { note.title }
              p(class: "nt-mt") do
                span { IconLabel(icon: "fa-regular fa-folder") { folder(note) } }
                span { Edited(at: note.updated_at) }
                note.tags.each { Tag(tag: it) }
              end
            end
          end
        end
      end
    end
  end
end
