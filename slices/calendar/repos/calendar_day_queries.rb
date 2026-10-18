# frozen_string_literal: true

module Calendar
  module Repos
    class CalendarDayQueries < Blog::DB::Repo
      NONE = Blog::Constants::EMPTY_ARRAY

      include Deps[
        sprint_queries: "tasks.repos.sprint_queries",
        event_queries: "repos.calendar_queries",
        journal_entry_queries: "record.repos.journal_entry_queries",
        post_queries: "posts.repos.post_queries",
        social_post_queries: "social.repos.social_post_queries",
      ]

      def between(from:, to:, include_hidden: true)
        held = held(from, to, include_hidden)

        (from..to).map { day(it, **held) }
      end

      private

      def by_day(rows) = rows.group_by { Blog::TimeZone.local_date(yield(it)) }

      def day(date, sprints:, posts:, social_posts:, journal:, events:)
        Structs::CalendarDay.new(
          date:, sprint: sprints[date], posts: posts.fetch(date, NONE), social_posts: social_posts.fetch(date, NONE),
          journal: journal.include?(date), events: events.select { (it.starts_on..it.ends_on).cover?(date) },
        )
      end

      def held(from, to, include_hidden)
        {
          events: event_queries.events_between(from:, to:, include_hidden:),
          sprints: sprint_queries.counted_between(from:, to:).to_h { [it.sprint_date, it] },
          posts: by_day(post_queries.calendar_between(from:, to:), &:published_at),
          social_posts: by_day(social_post_queries.calendar_between(from:, to:), &:posted_at),
          journal: journal_entry_queries.days_between(from, to).to_set,
        }
      end
    end
  end
end
