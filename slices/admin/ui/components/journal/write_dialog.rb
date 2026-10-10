# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Journal
        class WriteDialog < Component
          BODY_HEIGHT = "300px"
          ID = "journal-write"
          SCOPE = "journal-write"
          TITLE_ID = "journal-write-title"

          prop :today, Blog::Types::Date
          prop :body, Blog::Types::String, default: Blog::Constants::EMPTY_STRING
          prop :tags, Blog::Types::String, default: Blog::Constants::EMPTY_STRING
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
          prop :return_to, Blog::Types::String.optional, default: nil

          def view_template
            Dialog(id: ID, title_id: TITLE_ID, title:, class: "modal journal-modal", data:) do
              Form(**form_attributes) do
                input(type: "hidden", name: "modal", value: Blog::Constants::CHECKED)
                input(type: "hidden", name: "return_to", value: @return_to) if @return_to
                body_field
                foot
                FieldError(field: :tags, errors: @errors, scope: SCOPE)
              end
            end
          end

          private

          def body_field
            EntryFields(
              body: @body, tags: @tags, errors: @errors, height: BODY_HEIGHT, label: t(".body"), scope: SCOPE,
              placeholder: t(".placeholder"), autofocus: true, only: :body,
            )
          end

          def control(field) = FieldError.control_attributes(field, @errors, SCOPE)

          def data = { dialog: "static", dialog_show: (true if @errors.any?) }

          def foot
            div(class: "journal-modal-foot") do
              tags_field
              words
              span(class: "journal-modal-hint") do
                kbd(class: "kbd") { t(".save_key") }
                plain " #{t('.save_hint')}"
              end
              save_button
            end
          end

          def form_attributes
            { action: path(:admin_create_journal_entry), class: "journal-modal-form", data: { journal_entry: "" } }
          end

          def save_button
            Button(
              variant: :pri, small: true, type: "submit", disabled: EntryFields.blank?(@body),
              data: { journal_save: "" }, icon: "fa-solid fa-feather",
            ) { t(".save") }
          end

          def tags_attributes
            { class: "journal-modal-tags", name: "entry[tags]", value: @tags, aria: { label: t(".tags") },
              placeholder: t(".tags_placeholder") }
          end

          def tags_field
            input(**mix(control(:tags), tags_attributes))
          end

          def title = t(".title", date: l(@today, format: :short))

          def words
            span(class: "journal-words", data: { journal_words: "", one: t(".words.one"), other: t(".words.other") }) do
              t(".words", count: Blog::Helpers::Figures.words(@body))
            end
          end
        end
      end
    end
  end
end
