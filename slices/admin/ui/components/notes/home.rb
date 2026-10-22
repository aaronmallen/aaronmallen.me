# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class Home < Component
          prop :notes, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :tree, Blog::Types::Instance(Structs::NoteTree)
          prop :backlink_counts, Blog::Types::Hash
          prop :unwritten, Blog::Types::Array.of(Blog::Types::Hash)

          def view_template
            div(class: "stack") do
              Card(title: t(".recent"), empty: (t(".empty") if @notes.empty?)) { @notes.each { row(it) } }
              unwritten unless @unwritten.empty?
            end
          end

          private

          def backlinks(note)
            count = @backlink_counts.fetch(note.id, 0)
            return if count.zero?

            span { IconLabel(icon: "fa-solid fa-arrow-turn-down fa-flip-horizontal") { t(".backlinks", count:) } }
          end

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
                backlinks(note)
                note.tags.each { Tag(tag: it) }
              end
            end
          end

          def unwritten
            Card(title: t(".unwritten"), note: @unwritten.size.to_s, class: "nt-links") do
              ul { @unwritten.each { unwritten_row(it) } }
            end
          end

          def unwritten_row(link)
            li(class: "record-link-row") do
              span(class: "nt-ms") do
                span { link[:title] }
                span { t(".from", titles: link[:sources].join(", ")) }
              end
              ButtonForm(
                action: path(:admin_create_note), label: t(".create"), icon: :add,
                hidden: { title: link[:title], folder_id: link[:folder_id] },
              )
            end
          end
        end
      end
    end
  end
end
