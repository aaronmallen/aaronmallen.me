# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class Links < Component
          prop :note, Blog::Types::Instance(ROM::Struct)
          prop :backlinks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :links_out, Blog::Types::Array.of(Blog::Types::Hash)

          def view_template
            list(t(".backlinks"), @backlinks, t(".no_backlinks")) { backlink(it) }
            list(t(".links_out"), @links_out, t(".none")) { link_out(it) }
            Form(action: path(:admin_create_note), id: Prose::CREATE_FORM, hidden: true) do
              HiddenFields(values: { folder_id: @note.folder_id })
            end
          end

          private

          def backlink(source)
            li(class: "nt-bl") do
              a(class: "nt-blt", href: path(:admin_note, id: source.id)) do
                span { source.title }
                line = snippet(source.body)
                span(class: "nt-sn") { line } if line
              end
            end
          end

          def link_out(link)
            li(class: "record-link-row") do
              if link[:id]
                a(class: "record-link-title", href: path(:admin_note, id: link[:id])) { link[:title] }
              else
                button(
                  type: "submit", form: Prose::CREATE_FORM, name: "title", value: link[:title],
                  class: "record-link-title nt-miss",
                ) { link[:title] }
                span(class: "record-link-day") { t(".not_written") }
              end
            end
          end

          def list(title, rows, none, &)
            Card(title:, note: rows.size.to_s, class: "nt-links") do
              rows.empty? ? p(class: "hint") { none } : ul { rows.each(&) }
            end
          end

          def snippet(body)
            title = @note.title.downcase
            line = body.lines.find { |text| ::Markdown::WikiLinks.titles(text).any? { it.downcase == title } }

            ::Markdown::WikiLinks.plain(line) if line
          end
        end
      end
    end
  end
end
