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
          prop :saved_views, Blog::Types::Hash
          prop :streak, Blog::Types::Hash
          prop :today, Blog::Types::Date
          prop :words, Blog::Types::Integer
          prop :editing, Blog::Types::Hash.optional
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
          prop :search, Blog::Types::String, default: Blog::Constants::EMPTY_STRING
          prop :values, Blog::Types::Hash, default: BLANK_ENTRY
          prop :writing, Blog::Types::Bool, default: false

          def view_template
            PageHead(title: t(".heading"), sub:, sub_icon: "fa-solid fa-lock")

            Split do
              Filters(search:, entry_date: entry_date.iso8601, today: @today, errors: @errors,
                      saved_views: @saved_views, streak: @streak)
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
              word_count: Blog::Helpers::Figures.words(body), autofocus: @writing,
            )
          end

          def search = @search.strip

          def sub
            dotted(
              t(".private"),
              t(".never_public"),
              t(".entries", count: @entries),
              t(".words", count: @words),
            )
          end
        end
      end
    end
  end
end
