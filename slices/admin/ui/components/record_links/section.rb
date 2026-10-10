# frozen_string_literal: true

module Admin
  module UI
    module Components
      module RecordLinks
        class Section < Component
          prop :records, Blog::Types::Hash
          prop :kind, Blog::Types::RecordKind
          prop :find_path, Blog::Types::String
          prop :id, Blog::Types::Integer
          prop :fields, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }
          prop :label, Blog::Types::String.optional, default: nil

          def view_template
            Card(label: @label || t(".label"), title: t(".title"), class: "record-links") do
              Hint { t(".empty") } if links.empty?
              links.each { |kind, rows| KindGroup(kind:) { rows.each { row(it) } } }
              Picker(
                scope:, link_path: path(:"admin_link_#{@kind}_record", id: @id), find_path: @find_path, fields: @fields,
                **@records.slice(:query, :found, :errors),
              )
            end
          end

          private

          def links = @records.fetch(:links, Blog::Constants::EMPTY_HASH)

          def row(link)
            li(class: "record-link-row") do
              title(link)
              time(class: "record-link-day", datetime: link.day.iso8601) { l(link.day, format: :medium) }
              unlink_form(link)
            end
          end

          def scope = "#{@kind.tr('_', '-')}-#{@id}-record"

          def title(link)
            return span(class: "record-link-title") { link.title } unless link.url

            a(class: "record-link-title", href: link.url) { link.title }
          end

          def unlink_form(link)
            label = t(".remove", title: link.title)

            Form(action: path(:"admin_unlink_#{@kind}_record", id: @id, other_kind: link.kind, other_id: link.id)) do
              HiddenFields(values: @fields.compact)
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
