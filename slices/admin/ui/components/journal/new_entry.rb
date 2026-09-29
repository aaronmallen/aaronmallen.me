# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Journal
        class NewEntry < Component
          FORM_ID = "journal-entry"
          ROWS = 5

          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :date, Blog::Types::Date
          prop :errors, Blog::Types::Hash
          prop :today, Blog::Types::Date
          prop :word_count, Blog::Types::Integer
          prop :autofocus, Blog::Types::Bool, default: false

          def view_template
            Form(id: FORM_ID, action: path(:admin_create_journal_entry), data: form_data) do
              Card(title:) do |card|
                card.side { words }
                body_field
                tags_field
                div(class: "journal-new-foot") { save_button }
              end
            end
          end

          private

          def blank? = !@values[:body].match?(/\S/)

          def body_attributes
            {
              **FieldError.control_attributes(:body, @errors),
              name: "entry[body]",
              rows: ROWS,
              autofocus: @autofocus,
              placeholder: t(".placeholder"),
              data: { journal_body: "" },
            }
          end

          def body_field
            label(class: "sr-only", for: FieldError.id_for(:body)) { t(".body") }
            Textarea(value: @values[:body], **body_attributes)
            FieldError(field: :body, errors: @errors)
          end

          def form_data = { journal_entry: "", today: @today.iso8601, today_label: t(".today") }

          def save_button
            Button(variant: :pri, type: "submit", disabled: blank?, data: { journal_save: "" }) do
              i(class: "fa-regular fa-floppy-disk", aria: { hidden: "true" })
              span { t(".save") }
            end
          end

          def tags_field
            label(class: "sr-only", for: FieldError.id_for(:tags)) { t(".tags") }
            Input(
              **FieldError.control_attributes(:tags, @errors),
              name: "entry[tags]",
              value: @values[:tags],
              placeholder: t(".tags_placeholder"),
            )
            FieldError(field: :tags, errors: @errors)
          end

          def title = @date == @today ? t(".today") : l(@date, format: :full)

          def words
            span(class: "journal-words", data: { journal_words: "", one: t(".words.one"), other: t(".words.other") }) do
              t(".words", count: @word_count)
            end
          end
        end
      end
    end
  end
end
