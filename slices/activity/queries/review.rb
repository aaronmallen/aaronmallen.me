# frozen_string_literal: true

module Activity
  module Queries
    class Review
      include Deps[review_repo: "repos.review_repo"]

      JOURNAL = Blog::Types::ActivityKind["journal"]
      MONTH = Blog::Types::ReviewPeriod["month"]
      NONE = Blog::Constants::EMPTY_ARRAY
      POST = Blog::Types::ActivityKind["post"]
      SOCIAL = Blog::Types::ActivityKind["social"]

      def call(period:, on: Blog::TimeZone.today)
        from, to = range(Blog::Types::ReviewPeriod[period], on)

        Structs::Review.new(
          period:, from:, to:, **tasks(from, to), **records(from, to),
          commits: review_repo.commits(from:, to:), decisions: review_repo.decisions(from:, to:),
          worked: worked(from, to),
        )
      end

      private

      def month(on) = [Date.new(on.year, on.month, 1), Date.new(on.year, on.month, -1)]

      def range(period, on)
        return month(on) if period == MONTH

        monday = on - (on.cwday - 1)
        [monday, monday + 6]
      end

      def records(from, to)
        found = review_repo.records(from:, to:).group_by(&:type)

        {
          posts: found.fetch(POST, NONE),
          social_posts: found.fetch(SOCIAL, NONE),
          journal: Structs::ReviewJournal.from(found.fetch(JOURNAL, NONE)),
        }
      end

      def tasks(from, to)
        { done: review_repo.done(from:, to:).group_by(&:closed_on), carried: review_repo.carried(from:, to:) }
      end

      def worked(from, to)
        seconds = review_repo.seconds_by_day(from:, to:)

        (from..to).to_h { [it, seconds.fetch(it, 0)] }
      end
    end
  end
end
