# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Calendar
        class Show < View
          include Components::Calendar

          LIVE_TABLES = %w[
            calendar_events calendars journal_entries posts projects social_post_deliveries social_post_parts
            social_posts sprints task_comments task_contributors task_links task_series task_tags work_sessions
          ].freeze

          prop :month, Blog::Types::Date
          prop :today, Blog::Types::Date
          prop :days, Blog::Types::Array.of(Blog::Types::Instance(::Calendar::Structs::CalendarDay))
          prop :day, Blog::Types::Instance(::Calendar::Structs::CalendarDay)
          prop :tasks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :calendars, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :tones, Blog::Types::Hash
          prop :refused, Blog::Types::Hash.optional, default: nil

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            page_head

            div(class: "g-main", data: { calendar: "" }) do
              Card { Month(month: @month, today: @today, days: @days, picked: @day.date, tones: @tones) }
              Panel(day: @day, calendars: @calendars, tasks: @tasks, today: @today, tones: @tones, refused: @refused)
            end
          end

          private

          def page_head
            PageHead(title: t(".heading"), sub: l(@month, format: :month)) do
              Picker(calendars: @calendars, tones: @tones, day: @day.date)
              MonthPager(month: @month, today: @today)
            end
          end
        end
      end
    end
  end
end
