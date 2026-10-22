# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class Folder < Component
          prop :folder, Blog::Types::Instance(Structs::NoteTree)
          prop :tree, Blog::Types::Instance(Structs::NoteTree)
          prop :notes, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            div(class: "nt-doc") do
              section(class: "nt-page") do
                FolderBar(folder: @folder, tree: @tree)
                head
                index
              end
              FolderSettings(folder: @folder, tree: @tree)
            end
          end

          private

          def counts
            notes = t(".notes", count: @folder.count)
            folders = @folder.folders.size

            folders.zero? ? notes : dotted(notes, t(".folders", count: folders))
          end

          def description
            text = @folder.description
            p(class: "nt-fd") { text } unless text.strip.empty?
          end

          def filed = @filed ||= @notes.select { it.folder_id == @folder.id }

          def folder_row(folder)
            id = folder.id
            count = folder.count
            inner = folder.folders.size

            FolderRow(
              icon: "fa-regular fa-folder", href: path(:admin_note_folder, id:),
              menu: path(:admin_note_folder_menu, id:), title: folder.name,
            ) do
              p(class: "nt-mt") do
                span { count.zero? ? t(".empty_folder") : t(".notes", count:) }
                span { t(".folders", count: inner) } unless inner.zero?
              end
            end
          end

          def head
            div(class: "nt-fh") do
              h1(class: "nt-h") { IconLabel(icon: "fa-regular fa-folder-open nt-fi") { @folder.name } }
              description
              p(class: "nt-mt nt-fm") do
                span { counts }
                last_edit
              end
              tags
            end
          end

          def index
            div(class: "nt-ix") do
              @folder.folders.each { folder_row(it) }
              filed.each { FolderNote(note: it) }
              Empty { t(".empty") } if @folder.empty?
            end
          end

          def last_edit
            edited = @notes.first
            return unless edited

            span do
              plain t(".last_edited")
              whitespace
              Edited(at: edited.updated_at)
            end
          end

          def tags
            names = filed.flat_map(&:tags).uniq(&:name).sort_by(&:name)
            return if names.empty?

            div(class: "nt-tags") { names.each { Tag(tag: it) } }
          end
        end
      end
    end
  end
end
