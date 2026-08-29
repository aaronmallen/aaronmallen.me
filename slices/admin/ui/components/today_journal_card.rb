# frozen_string_literal: true

module Admin
  module UI
    module Components
      class TodayJournalCard < Component
        FORM_ID = "today-journal-entry"
        ROWS = 4
        SEPARATOR = " · "

        prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
        prop :body, Blog::Types::String
        prop :errors, Blog::Types::Hash
        prop :word_count, Blog::Types::Integer

        def view_template
          Card(label: t(".label"), title: t(".title")) do |card|
            card.side { span(class: "journal-words") { t(".today", count: @entries.size) } }
            entry_form
            entry_list
          end
        end

        private

        def body_attributes
          {
            **Journal::FieldError.control_attributes(:body, @errors),
            name: "entry[body]",
            rows: ROWS,
            placeholder: t(".placeholder"),
            data: { journal_body: "" },
          }
        end

        def body_field
          label(class: "sr-only", for: Journal::FieldError.id_for(:body)) { t(".body") }
          Textarea(value: @body, **body_attributes)
          Journal::FieldError(field: :body, errors: @errors)
        end

        def entry_form
          Form(**form_attributes) do
            body_field
            foot
          end
        end

        def entry_list
          return if @entries.empty?

          div(class: "today-journal-entries") { @entries.each { entry_row(it) } }
        end

        def entry_row(entry)
          clock = l(entry.entry_time, format: :clock)

          article(class: "today-journal-entry") do
            time(class: "today-journal-time", datetime: "#{entry.entry_date.iso8601}T#{clock}") { clock }
            div(class: "journal-entry-body") { entry.body }
          end
        end

        def foot
          div(class: "today-journal-foot") do
            meta
            save_button
          end
        end

        def form_attributes
          { id: FORM_ID, action: path(:admin_create_today_journal_entry), data: { journal_entry: "" } }
        end

        def meta
          p(class: "journal-words") do
            i(class: "fa-solid fa-lock today-journal-lock", aria: { hidden: "true" })
            plain "#{t('.private')}#{SEPARATOR}"
            span(data: { journal_words: "", one: t(".words.one"), other: t(".words.other") }) do
              t(".words", count: @word_count)
            end
          end
        end

        def save_button
          Button(variant: :pri, type: "submit", disabled: !@body.match?(/\S/), data: { journal_save: "" }) do
            i(class: "fa-regular fa-floppy-disk", aria: { hidden: "true" })
            span { t(".save") }
          end
        end
      end
    end
  end
end
