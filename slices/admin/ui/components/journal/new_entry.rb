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
            Form(id: FORM_ID, action: path(:admin_create_journal_entry), data: form_data) do
              Card(title:) do |card|
                card.side { words }
                EntryFields(
                  body: @values[:body], tags: @values[:tags], errors: @errors, height: BODY_HEIGHT,
                  label: t(".body"), placeholder: t(".placeholder"), autofocus: @autofocus,
                )
                div(class: "journal-new-foot") { save_button }
              end
            end
          end

          private

          def form_data = { journal_entry: "", today: @today.iso8601, today_label: t(".today") }

          def save_button
            blank = EntryFields.blank?(@values[:body])
            Button(variant: :pri, type: "submit", disabled: blank, data: { journal_save: "" }) do
              i(class: "fa-regular fa-floppy-disk", aria: { hidden: "true" })
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
