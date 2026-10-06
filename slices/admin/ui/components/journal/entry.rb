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

          def view_template
            article(class: "journal-entry", data: { journal_item: "" }) do
              head
              Body(body: @entry.body, hidden: editing?, data: { journal_text: "" })
              edit_form
              linked if records
            end
          end

          private

          def actions
            div(class: "journal-entry-actions", hidden: editing?, data: { journal_actions: "" }) do
              Button(small: true, data: { journal_edit: "" }) { t(".edit") }
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
              Button(variant: :warn, small: true, type: "submit") { t(".delete") }
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
                save_button
              end
            end
          end

          def editing? = !@editing.nil?

          def errors = editing? ? @editing[:errors] : Blog::Constants::EMPTY_HASH

          def head
            header(class: "journal-entry-head") do
              clock = l(@entry.entry_time, format: :clock)
              time(datetime: "#{@date.iso8601}T#{clock}") { clock }
              @entry.tags.each { Tag(tag: it, href: path(:admin_journal, q: "tag:#{it.name}")) }
              actions
            end
          end

          def linked
            id = @entry.id

            div(class: "journal-links", data: { journal_links: "" }) do
              RecordLinks::Section(
                records:, scope: "journal-entry-#{id}-record", id:, fields: { to: @date.iso8601, edit: id },
                unlink_route: :admin_unlink_journal_entry_record, find_path: path(:admin_journal),
                link_path: path(:admin_link_journal_entry_record, id:),
              )
            end
          end

          def links_link
            a(class: "btn sm", href: path(:admin_journal, to: @date.iso8601, edit: @entry.id)) do
              i(class: "fa-solid fa-link", aria: { hidden: "true" })
              span { t(".links") }
            end
          end

          def records = @editing&.fetch(:records, nil)

          def save_button
            blank = EntryFields.blank?(body)
            Button(variant: :pri, small: true, type: "submit", disabled: blank, data: { journal_save: "" }) do
              t(".save")
            end
          end

          def scope = "journal-edit-#{@entry.id}"

          def tags = editing? ? @editing[:tags] : @entry.tags.map(&:name).join(TAG_SEPARATOR)
        end
      end
    end
  end
end
