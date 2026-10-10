# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Journal
        class Index < View
          include Components::Journal

          BLANK_ENTRY = {
            body: Blog::Constants::EMPTY_STRING,
            entry_date: nil,
            tags: Blog::Constants::EMPTY_STRING,
          }.freeze

          prop :days, Blog::Types::Instance(Blog::Structs::DayPaged)
          prop :entries, Blog::Types::Integer
          prop :linked, Blog::Types::Hash
          prop :saved_views, Blog::Types::Hash
          prop :streak, Blog::Types::Hash
          prop :today, Blog::Types::Date
          prop :words, Blog::Types::Integer
          prop :editing, Blog::Types::Hash.optional
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
          prop :search, Blog::Types::String, default: Blog::Constants::EMPTY_STRING
          prop :values, Blog::Types::Hash, default: BLANK_ENTRY
          prop :writing, Blog::Types::Bool, default: false
          prop :written, Blog::Types::Hash.optional, default: nil

          def view_template
            content_for(:journal_write) { capture { WriteDialog(today: @today, **@written) } } if @written
            PageHead(title: t(".heading"), sub:, sub_icon: "fa-solid fa-lock") do |head|
              head.tabs_side { SavedViews(**@saved_views) }
              search_form
            end

            div(class: "g-main rev") do
              new_entry
              section(class: "journal-days", aria: { label: t(".entries_label") }) { days }
            end
          end

          private

          def body = @values[:body]

          def days
            return Empty { t(search.empty? ? ".empty" : ".no_match") } if @days.rows.empty?

            @days.rows.each do |(date, entries)|
              Day(date:, entries:, today: @today, editing: @editing, linked: @linked)
            end
            Pager(page: @days, route: :admin_journal, params: search.empty? ? {} : { q: search })
          end

          def entry_date = @values[:entry_date] || @today

          def new_entry
            NewEntry(
              values: { body:, tags: @values[:tags] }, date: entry_date, errors: @errors, today: @today,
              word_count: Blog::Helpers::Figures.words(body), autofocus: @writing,
            )
          end

          def search = @search.strip

          def search_form
            form(action: path(:admin_journal), method: "get", role: "search", class: "journal-search") do
              label(class: "sr-only", for: "journal-search") { t(".search") }
              Input(id: "journal-search", type: "search", name: "q", value: @search,
                    placeholder: t(".search_placeholder"))
            end
          end

          def sub
            dotted(
              t(".private"),
              t(".never_public"),
              t(".entries", count: @entries),
              t(".words", count: @words),
              t(".streak", written: @streak[:written], days: @streak[:days]),
            )
          end
        end
      end
    end
  end
end
