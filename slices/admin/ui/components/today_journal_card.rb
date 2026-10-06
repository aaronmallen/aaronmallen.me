# frozen_string_literal: true

module Admin
  module UI
    module Components
      class TodayJournalCard < Component
        BODY_HEIGHT = "160px"
        FORM_ID = "today-journal-entry"
        SEPARATOR = " · "

        prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
        prop :body, Blog::Types::String
        prop :errors, Blog::Types::Hash
        prop :tags, Blog::Types::String
        prop :word_count, Blog::Types::Integer

        def view_template
          Card(label: t(".label"), title: t(".title")) do |card|
            card.side { span(class: "journal-words") { t(".today", count: @entries.size) } }
            entry_form
            entry_list
          end
        end

        private

        def entry_form
          Form(**form_attributes) do
            Journal::EntryFields(
              body: @body, tags: @tags, errors: @errors, height: BODY_HEIGHT, label: t(".body"),
              placeholder: t(".placeholder"),
            )
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
            Journal::Body(body: entry.body)
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
            Icon("fa-solid fa-lock today-journal-lock")
            plain "#{t('.private')}#{SEPARATOR}"
            span(data: { journal_words: "", one: t(".words.one"), other: t(".words.other") }) do
              t(".words", count: @word_count)
            end
          end
        end

        def save_button
          blank = Journal::EntryFields.blank?(@body)
          Button(variant: :pri, type: "submit", disabled: blank, data: { journal_save: "" }) do
            i(class: "fa-regular fa-floppy-disk", aria: { hidden: "true" })
            span { t(".save") }
          end
        end
      end
    end
  end
end
