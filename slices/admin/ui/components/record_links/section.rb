# frozen_string_literal: true

module Admin
  module UI
    module Components
      module RecordLinks
        class Section < Component
          ICONS = {
            Blog::Types::RecordKind["commit"] => "fa-code-commit",
            Blog::Types::RecordKind["decision"] => "fa-scale-balanced",
            Blog::Types::RecordKind["journal_entry"] => "fa-feather",
            Blog::Types::RecordKind["post"] => "fa-file-lines",
            Blog::Types::RecordKind["project"] => "fa-cube",
            Blog::Types::RecordKind["pull_request"] => "fa-code-pull-request",
            Blog::Types::RecordKind["social_post"] => "fa-paper-plane",
            Blog::Types::RecordKind["task"] => "fa-list-check",
            Blog::Types::RecordKind["work_entry"] => "fa-briefcase",
          }.freeze
          KINDS = "ui.components.record_links.kinds"

          prop :records, Blog::Types::Hash
          prop :kind, Blog::Types::RecordKind
          prop :find_path, Blog::Types::String
          prop :id, Blog::Types::Integer
          prop :fields, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }
          prop :label, Blog::Types::String.optional, default: nil

          def self.kind_name_key(kind) = [KINDS, kind].join(".")

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
