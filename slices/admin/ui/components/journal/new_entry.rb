# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Journal
        class NewEntry < Component
          BODY_HEIGHT = "240px"
          FORM_ID = "journal-entry"

          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :date, Blog::Types::Date
          prop :errors, Blog::Types::Hash
          prop :today, Blog::Types::Date
          prop :word_count, Blog::Types::Integer
          prop :autofocus, Blog::Types::Bool, default: false

          def view_template
            Form(id: FORM_ID, action: path(:admin_create_journal_entry), class: "journal-compose", data: form_data) do
              Card(title:, class: "jbox") do |card|
                card.side { private_note }
                fields(:body, placeholder: t(".placeholder"), autofocus: @autofocus)
                foot
              end
            end
          end

          private

          def date_attributes
            {
              type: "date", name: "entry[entry_date]", value: @date.iso8601, max: @today.iso8601, form: FORM_ID,
              data: { journal_date: "" },
            }
          end

          def date_field
            control = FieldError.control_attributes(:entry_date, @errors, FieldError::SCOPE)

            label(class: "sr-only", for: control[:id]) { t(".entry_date") }
            Input(**control, **date_attributes)
            FieldError(field: :entry_date, errors: @errors)
          end

          def fields(only, **)
            EntryFields(
              body: @values[:body], tags: @values[:tags], errors: @errors, height: BODY_HEIGHT, label: t(".body"),
              only:, **,
            )
          end

          def foot
            div(class: "jbox-foot") do
              date_field
              fields(:tags)
              words
              save_button
            end
          end

          def form_data = { journal_entry: "", today: @today.iso8601, today_label: t(".today") }

          def private_note
            span(class: "journal-words") do
              Icon("fa-solid fa-lock")
              plain " #{t('.private')}"
            end
          end

          def save_button
            blank = EntryFields.blank?(@values[:body])
            Button(variant: :pri, small: true, type: "submit", disabled: blank, data: { journal_save: "" }) do
              i(class: "fa-solid fa-feather", aria: { hidden: "true" })
              span { t(".save") }
            end
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
