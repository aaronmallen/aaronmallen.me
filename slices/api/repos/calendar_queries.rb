# frozen_string_literal: true

require "dry/monads"

module API
  module Repos
    class CalendarQueries < Blog::DB::Repo
      NONE = Blog::Constants::EMPTY_ARRAY

      include Dry::Monads[:result]
      include Deps[
        sprint_queries: "tasks.repos.sprint_queries",
        journal_entry_queries: "record.repos.journal_entry_queries",
        post_queries: "posts.repos.post_queries",
        social_post_queries: "social.repos.social_post_queries",
      ]

      def between(from:, to:)
        return Failure(Blog::Helpers::DayWindow::TOO_LONG) if Blog::Helpers::DayWindow.too_long?(from, to)

        Success(days(from, to))
      end

      private

      def by_day(rows) = rows.group_by { Blog::TimeZone.today(yield(it)) }

      def day(date, sprints:, posts:, social_posts:, journal:)
        Structs::CalendarDay.new(
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
          sprints: sprint_queries.counted_between(from:, to:).to_h { [it.sprint_date, it] },
          posts: by_day(post_queries.calendar_between(from:, to:), &:published_at),
          social_posts: by_day(social_post_queries.calendar_between(from:, to:), &:posted_at),
          journal: journal_entry_queries.days_between(from, to).to_set,
        }
      end
    end
  end
end
