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
          SEPARATOR = " · "

          def initialize(
            days:, entries:, streak:, today:, words:, editing: nil, errors: Blog::Constants::EMPTY_HASH,
            search: Blog::Constants::EMPTY_STRING, values: BLANK_ENTRY, writing: false
          )
            super()
            @counts = { entries:, words: }
            @days = days
            @editing = editing
            @errors = errors
            @search = search
            @streak = streak
            @today = today
            @values = values
            @writing = writing
          end

          def view_template
            PageHead(title: t(".heading"), sub:, sub_icon: "fa-solid fa-lock")

            Split do
              Filters(search:, entry_date: entry_date.iso8601, today: @today, streak: @streak, errors: @errors)
              div(class: "journal-main") do
                new_entry
                days
              end
            end
          end

          private

          def body = @values[:body]

          def days
            return Empty { t(search.empty? ? ".empty" : ".no_match") } if @days.rows.empty?

            @days.rows.each { |(date, entries)| Day(date:, entries:, today: @today, editing: @editing) }
            Pager(page: @days, route: :admin_journal, params: search.empty? ? {} : { q: search })
          end

          def entry_date = @values[:entry_date] || @today

          def new_entry
            NewEntry(
              values: { body:, tags: @values[:tags] }, date: entry_date, errors: @errors, today: @today,
              word_count: Blog::Figures.words(body), autofocus: @writing,
            )
          end

          def search = @search.strip

          def sub
            [
              t(".private"),
              t(".never_public"),
              t(".entries", count: @counts[:entries]),
              t(".words", count: @counts[:words]),
            ].join(SEPARATOR)
          end
        end
      end
    end
  end
end
