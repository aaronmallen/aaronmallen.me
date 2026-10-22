# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class FolderLinks < Component
          KIND = Blog::Types::RecordKind["note_folder"]

          prop :folder, Blog::Types::Instance(Structs::NoteTree)
          prop :records, Blog::Types::Hash
          prop :from_folders, Blog::Types::Array

          def view_template
            id = @folder.id

            div(class: "nt-facts") do
              RecordLinks::Section(
                records: @records, kind: KIND, id:, find_path: path(:admin_note_folder, id:), card: false,
              )
              Hint { t(".applies", name: @folder.name, count: @folder.count) }
            end
            parents unless @from_folders.empty?
          end

          private

          def kind_label(kind) = t(Blog::Helpers::RecordKinds.fetch(kind).label).downcase

          def parents
            Card(title: t(".from_parents"), class: "record-links") do
              @from_folders.group_by(&:first).each do |folder, pairs|
                div(class: "record-link-group") do
                  h3(class: "record-link-kind") { IconLabel(icon: "fa-regular fa-folder") { folder.path } }
                  ul(class: "record-link-list") { pairs.each { row(it.last) } }
                end
              end
            end
          end

          def row(link)
            li(class: "record-link-row") do
              a(class: "record-link-title", href: link.url) { link.title } if link.url
              span(class: "record-link-title") { link.title } unless link.url
              span(class: "record-link-day") { kind_label(link.kind) }
            end
          end
        end
      end
    end
  end
end
