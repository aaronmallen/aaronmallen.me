# frozen_string_literal: true

require "dry/monads"

module API
  module Queries
    class Calendar
      BACKWARDS = "from comes after to"
      LONGEST = 366
      NONE = Blog::Constants::EMPTY_ARRAY
      TOO_LONG = "give a range of #{LONGEST} days or fewer".freeze

      Day = Data.define(:date, :sprint, :posts, :social_posts, :journal)

      include Dry::Monads[:result]
      include Deps[
        calendar_posts: "posts.queries.calendar_posts",
        calendar_social_posts: "social.queries.calendar_social_posts",
        counted_sprints_between: "tasks.queries.counted_sprints_between",
        journal_days_between: "record.queries.journal_days_between",
      ]

      def call(from:, to:)
        return Failure(BACKWARDS) if from > to
        return Failure(TOO_LONG) if to - from >= LONGEST

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
          journal: journal_days_between.call(from:, to:).to_set,
        }
      end
    end
  end
end
