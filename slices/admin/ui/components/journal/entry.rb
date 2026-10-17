# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Journal
        class Entry < Component
          prop :entry, Blog::Types::Instance(ROM::Struct)
          prop :date, Blog::Types::Date
          prop :editing, Blog::Types::Hash.optional, default: nil
          prop :linked, Blog::Types::Integer, default: 0
          prop :place, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def self.links_id(id) = "journal-links-#{id}"

          def view_template
            article(class: "journal-entry", data:) do
              head
              div(class: "post-body journal-entry-body", hidden: editing?, data: { journal_text: "" }) do
                raw(safe(@entry.body_html.strip))
              end
              edit_form if editing?
              linked if records
            end
          end

          private

          def actions
            div(class: "journal-entry-actions hov", hidden: editing?, data: { journal_actions: "" }) do
              Button(**icon(t(".edit"), :edit), data: { journal_edit: "" })
              links_link
              delete_form
            end
          end

          def data
            {
              journal_item: "", menu:, journal_source: @entry.body, journal_tags: saved_tags, journal_scope: scope,
              journal_update: update_path,
            }
          end

          def delete_form
            DeleteForm(
              action: path(:admin_delete_journal_entry, id: @entry.id), label: t(".delete"), icon_only: true,
              confirm: t(".confirm_delete"), hidden: @place,
            )
          end

          def edit_form
            EditForm(
              action: update_path, body: @editing[:body], tags: @editing[:tags], errors: @editing[:errors], scope:,
              source: @entry.body, place: @place,
            )
          end

          def editing? = !@editing.nil?

          def head
            header(class: "journal-entry-head") do
              clock = l(@entry.entry_time, format: :clock)
              time(datetime: "#{@date.iso8601}T#{clock}") { clock }
              @entry.tags.each { Tag(tag: it) }
              linked_count
              actions
            end
          end

          def icon(label, name)
            { small: true, label:, icon: name }
          end

          def linked
            id = @entry.id

            div(class: "journal-links", id: self.class.links_id(id), data: { journal_links: "" }) do
              RecordLinks::Section(
                records:, kind: "journal_entry", id:, fields: { to: @date.iso8601, edit: id },
                find_path: path(:admin_journal),
              )
            end
          end

          def linked_count
            return if @linked.zero?

            span(class: "journal-linked") do
              Icon("fa-solid fa-link")
              plain t(".linked", count: @linked)
            end
          end

          def links_link
            Button(href: path(:admin_journal, to: @date.iso8601, edit: @entry.id),
                   **icon(t(".links"), "fa-solid fa-link"))
          end

          def menu = path(:admin_journal_entry_menu, id: @entry.id)

          def records = @editing&.fetch(:records, nil)

          def saved_tags = Blog::Types::TagField[@entry.tags]

          def scope = "journal-edit-#{@entry.id}"

          def update_path = path(:admin_update_journal_entry, id: @entry.id)
        end
      end
    end
  end
end
