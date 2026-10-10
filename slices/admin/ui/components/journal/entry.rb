# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Journal
        class Entry < Component
          BODY_HEIGHT = "200px"
          TAG_SEPARATOR = ", "

          prop :entry, Blog::Types::Instance(ROM::Struct)
          prop :date, Blog::Types::Date
          prop :editing, Blog::Types::Hash.optional, default: nil
          prop :linked, Blog::Types::Integer, default: 0

          def view_template
            article(class: "journal-entry", data: { journal_item: "" }) do
              head
              MarkdownBody(
                source: @entry.body, markdown: ::Posts::Markdown, class: "journal-entry-body", hidden: editing?,
                data: { journal_text: "" },
              )
              edit_form
              linked if records
            end
          end

          private

          def actions
            div(class: "journal-entry-actions hov", hidden: editing?, data: { journal_actions: "" }) do
              Button(**icon(t(".edit"), "fa-regular fa-pen-to-square"), data: { journal_edit: "" })
              links_link
              delete_form
            end
          end

          def body = editing? ? @editing[:body] : @entry.body

          def delete_attributes
            {
              action: path(:admin_delete_journal_entry, id: @entry.id),
              data: { confirm: t(".confirm_delete") },
            }
          end

          def delete_form
            Form(**delete_attributes) do
              Button(**icon(t(".delete"), "fa-regular fa-trash-can"), variant: :warn, type: "submit")
            end
          end

          def edit_attributes
            {
              action: path(:admin_update_journal_entry, id: @entry.id),
              class: "journal-edit",
              hidden: !editing?,
              data: { journal_edit_form: "", journal_source: @entry.body },
            }
          end

          def edit_form
            Form(**edit_attributes) do
              EntryFields(body:, tags:, errors:, scope:, height: BODY_HEIGHT, label: t(".body"))
              div(class: "journal-edit-foot") do
                Button(small: true, data: { journal_cancel: "" }) { t(".cancel") }
                SaveButton(body:) { t(".save") }
              end
            end
          end

          def editing? = !@editing.nil?

          def errors = editing? ? @editing[:errors] : Blog::Constants::EMPTY_HASH

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
            { small: true, title: label, aria: { label: }, icon: name }
          end

          def linked
            id = @entry.id

            div(class: "journal-links", data: { journal_links: "" }) do
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

          def records = @editing&.fetch(:records, nil)

          def scope = "journal-edit-#{@entry.id}"

          def tags = editing? ? @editing[:tags] : @entry.tags.map(&:name).join(TAG_SEPARATOR)
        end
      end
    end
  end
end
