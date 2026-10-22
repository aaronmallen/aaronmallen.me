# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class FolderNote < Component
          CODE = /\A(sql|ruby|```)/
          LEAD = /\A[#>\-*\d.\s]+/
          WIKI_LINK = /\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/

          prop :note, Blog::Types::Instance(ROM::Struct)

          def view_template
            id = @note.id
            text = excerpt

            FolderRow(
              icon: "fa-regular fa-file-lines", href: path(:admin_note, id:), menu: path(:admin_note_menu, id:),
              title: @note.title, pinned: @note.pinned,
            ) do
              p(class: "nt-ex") { text } if text
              meta
            end
          end

          private

          def excerpt
            @note.body.each_line.lazy.map { plain_line(it) }.find { it.match?(/\w/) && !it.match?(CODE) }
          end

          def meta
            p(class: "nt-mt") do
              span { Edited(at: @note.updated_at) }
              span { t(".words", count: Blog::Helpers::Figures.words(@note.body)) }
              @note.tags.each { Tag(tag: it) }
            end
          end

          def plain_line(line)
            line.gsub(WIKI_LINK) do
              (Regexp.last_match(2) || Regexp.last_match(1)).strip
            end.sub(LEAD, "").delete("*_`").strip
          end
        end
      end
    end
  end
end
