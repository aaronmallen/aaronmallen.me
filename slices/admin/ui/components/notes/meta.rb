# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class Meta < Component
          prop :note, Blog::Types::Instance(ROM::Struct)
          prop :tree, Blog::Types::Instance(Structs::NoteTree)
          prop :backlinks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :links_out, Blog::Types::Array.of(Blog::Types::Hash)
          prop :records, Blog::Types::Hash
          prop :from_folders, Blog::Types::Array

          def view_template
            aside(class: "nt-meta") do
              div(class: "nt-facts") do
                folder_field
                facts
              end
              Links(note: @note, backlinks: @backlinks, links_out: @links_out)
              Linked(note: @note, records: @records, from_folders: @from_folders)
              div { delete }
            end
          end

          private

          def delete
            ButtonForm(
              action: path(:admin_delete_note, id: @note.id), label: t(".delete"), variant: :gh, icon: :trash,
              confirm: t(".confirm_delete", title: @note.title, count: @backlinks.size),
            )
          end

          def facts
            p(class: "nt-mt") do
              span { t(".created", date: l(Blog::TimeZone.local(@note.created_at).to_date, format: :short)) }
              span { t(".words", count: Blog::Helpers::Figures.words(@note.body)) }
              span { IconLabel(icon: "fa-solid fa-lock") { t(".private") } }
            end
          end

          def folder_field
            AutoForm(method: "post", action: path(:admin_move_note, id: @note.id), data: { morph: true }) do
              Field(label: t(".folder"), id: "note-folder") do |control|
                folder = @tree.path_of(@note.folder_id)
                Input(**control, name: "path", value: folder, list: "note-folders", placeholder: t(".top_level"))
              end
              datalist(id: "note-folders") { @tree.all.each { option(value: it.path) } }
            end
          end
        end
      end
    end
  end
end
