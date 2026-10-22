# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class Linked < Component
          KIND = Blog::Types::RecordKind["note"]

          prop :note, Blog::Types::Instance(ROM::Struct)
          prop :records, Blog::Types::Hash
          prop :from_folders, Blog::Types::Array

          def view_template
            id = @note.id

            div(class: "nt-facts") do
              RecordLinks::Section(records: @records, kind: KIND, id:, find_path: path(:admin_note, id:), card: false)
              from_folders unless @from_folders.empty?
            end
          end

          private

          def from_folders
            Field(label: t(".from_folders")) do
              ul(class: "record-link-list") do
                @from_folders.each do |folder, link|
                  li(class: "record-link-row") do
                    title(link)
                    span(class: "record-link-day") { t(".via", folder: folder.name) }
                  end
                end
              end
            end
          end

          def title(link)
            return span(class: "record-link-title") { link.title } unless link.url

            a(class: "record-link-title", href: link.url) { link.title }
          end
        end
      end
    end
  end
end
