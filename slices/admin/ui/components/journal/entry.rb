# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Journal
        class Entry < Component
          TAG_SEPARATOR = ", "

          prop :entry, Blog::Types::Instance(ROM::Struct)
          prop :date, Blog::Types::Date
          prop :editing, Blog::Types::Hash.optional, default: nil

          def view_template
            article(class: "journal-entry", data: { journal_item: "" }) do
              head
              Body(body: @entry.body, hidden: editing?, data: { journal_text: "" })
              edit_form
            end
          end

          private

          def actions
            div(class: "journal-entry-actions", hidden: editing?, data: { journal_actions: "" }) do
              Button(small: true, data: { journal_edit: "" }) { t(".edit") }
              delete_form
            end
          end

          def body = editing? ? @editing[:body] : @entry.body

          def body_field
            label(class: "sr-only", for: FieldError.id_for(:body, scope)) { t(".body") }
            Textarea(
              **FieldError.control_attributes(:body, errors, scope),
              value: body,
              name: "entry[body]",
              rows: NewEntry::ROWS,
              data: { journal_body: "" },
            )
            FieldError(field: :body, errors:, scope:)
          end

          def delete_attributes
            {
              action: path(:admin_delete_journal_entry, id: @entry.id),
              data: { journal_delete: "", confirm: t(".confirm_delete") },
            }
          end

          def delete_form
            Form(**delete_attributes) do
              Button(variant: :warn, small: true, data: { journal_delete_button: "" }) { t(".delete") }
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
              body_field
              tags_field
              div(class: "journal-edit-foot") do
                Button(small: true, data: { journal_cancel: "" }) { t(".cancel") }
                save_button
              end
            end
          end

          def editing? = !@editing.nil?

          def errors = editing? ? @editing[:errors] : Dry::Core::Constants::EMPTY_HASH

          def head
            header(class: "journal-entry-head") do
              clock = l(@entry.entry_time, format: :clock)
              time(datetime: "#{@date.iso8601}T#{clock}") { clock }
              @entry.tags.each { |tag| Pill(color: Blog::UI::Components::Pill.for_tag_color(tag.color)) { tag.name } }
              actions
            end
          end

          def save_button
            blank = !body.match?(/\S/)
            Button(variant: :pri, small: true, type: "submit", disabled: blank, data: { journal_save: "" }) do
              t(".save")
            end
          end

          def scope = "journal-edit-#{@entry.id}"

          def tags = editing? ? @editing[:tags] : @entry.tags.map(&:name).join(TAG_SEPARATOR)

          def tags_field
            label(class: "sr-only", for: FieldError.id_for(:tags, scope)) { t(".tags") }
            Input(
              **FieldError.control_attributes(:tags, errors, scope),
              value: tags,
              name: "entry[tags]",
              placeholder: t(".tags_placeholder"),
            )
            FieldError(field: :tags, errors:, scope:)
          end
        end
      end
    end
  end
end
