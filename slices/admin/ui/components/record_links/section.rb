# frozen_string_literal: true

module Admin
  module UI
    module Components
      module RecordLinks
        class Section < Component
          KINDS = "ui.components.record_links.kinds"

          prop :records, Blog::Types::Hash
          prop :scope, Blog::Types::String
          prop :link_path, Blog::Types::String
          prop :find_path, Blog::Types::String
          prop :id, Blog::Types::Integer
          prop :unlink_route, Blog::Types::Symbol
          prop :fields, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }
          prop :label, Blog::Types::String.optional, default: nil

          def self.kind_name_key(kind) = [KINDS, kind].join(".")

          def view_template
            Card(label: @label || t(".label"), title: t(".title"), class: "record-links") do
              links.empty? ? Hint { t(".empty") } : links.each { |kind, rows| group(kind, rows) }
              Picker(
                scope: @scope, link_path: @link_path, find_path: @find_path, fields: @fields,
                **@records.slice(:query, :found, :errors),
              )
            end
          end

          private

          def group(kind, rows)
            div(class: "record-link-group") do
              h3(class: "record-link-kind") { t(self.class.kind_name_key(kind)) }
              ul(class: "record-link-list") { rows.each { row(it) } }
            end
          end

          def links = @records.fetch(:links, Blog::Constants::EMPTY_HASH)

          def row(link)
            li(class: "record-link-row") do
              title(link)
              time(class: "record-link-day", datetime: link.day.iso8601) { l(link.day, format: :medium) }
              unlink_form(link)
            end
          end

          def title(link)
            return span(class: "record-link-title") { link.title } unless link.url

            a(class: "record-link-title", href: link.url) { link.title }
          end

          def unlink_form(link)
            label = t(".remove", title: link.title)

            Form(action: path(@unlink_route, id: @id, other_kind: link.kind, other_id: link.id)) do
              @fields.compact.each { |name, value| input(type: "hidden", name: name.to_s, value:) }
              Button(
                type: "submit", variant: :gh, small: true, title: label, aria: { label: }, icon: "fa-solid fa-xmark",
              )
            end
          end
        end
      end
    end
  end
end
