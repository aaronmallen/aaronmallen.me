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

        def body_field
          div(class: "journal-editor") { MarkdownEditor(**body_props) }
          Journal::FieldError(field: :body, errors: @errors)
        end

        def body_props
          {
            **Journal::FieldError.control_attributes(:body, @errors),
            name: "entry[body]", value: @body, height: BODY_HEIGHT, renderer: "posts", label: t(".body"),
            placeholder: t(".placeholder"), data: { journal_body: "" },
          }
        end

        def entry_form
          Form(**form_attributes) do
            body_field
            tags_field
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
          Button(variant: :pri, type: "submit", disabled: !@body.match?(/\S/), data: { journal_save: "" }) do
            i(class: "fa-regular fa-floppy-disk", aria: { hidden: "true" })
            span { t(".save") }
          end
        end

        def tags_field
          label(class: "sr-only", for: Journal::FieldError.id_for(:tags)) { t(".tags") }
          Input(
            **Journal::FieldError.control_attributes(:tags, @errors),
            name: "entry[tags]",
            value: @tags,
            placeholder: t(".tags_placeholder"),
          )
          Journal::FieldError(field: :tags, errors: @errors)
        end
      end
    end
  end
end
