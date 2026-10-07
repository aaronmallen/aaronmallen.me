# frozen_string_literal: true

require "dry/monads"

module API
  module Queries
    class Calendar
      NONE = Blog::Constants::EMPTY_ARRAY

      Day = Data.define(:date, :sprint, :posts, :social_posts, :journal)

      include Dry::Monads[:result]
      include Deps[
        calendar_posts: "posts.queries.calendar_posts",
        calendar_social_posts: "social.queries.calendar_social_posts",
        counted_sprints_between: "tasks.queries.counted_sprints_between",
        journal_entry_queries: "record.repos.journal_entry_queries",
      ]

      def call(from:, to:)
        return Failure(Blog::DayWindow::TOO_LONG) if Blog::DayWindow.too_long?(from, to)

        Success(days(from, to))
      end

      private

      def by_day(rows) = rows.group_by { Blog::TimeZone.today(yield(it)) }

      def day(date, sprints:, posts:, social_posts:, journal:)
        Day.new(
          date:, sprint: sprints[date], posts: posts.fetch(date, NONE), social_posts: social_posts.fetch(date, NONE),
          journal: journal.include?(date),
        )
      end

      def days(from, to)
        held = held(from, to)

        (from..to).map { day(it, **held) }
      end

      def held(from, to)
        {
          sprints: counted_sprints_between.call(from:, to:).to_h { [it.sprint_date, it] },
          posts: by_day(calendar_posts.call(from:, to:), &:published_at),
          social_posts: by_day(calendar_social_posts.call(from:, to:), &:posted_at),
          journal: journal_entry_queries.days_between(from, to).to_set,
        }
      end
    end
  end
end
