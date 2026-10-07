# frozen_string_literal: true

module Admin
  module Operations
    class BuildReviewPage
      include Deps[
        activity_queries: "activity.repos.activity_queries",
        review_queries: "activity.repos.review_queries",
        review_note: "record.queries.review_note",
      ]

      def call(period: nil, day: nil, today: Blog::TimeZone.today, **credit)
        on = Blog::Types::DateParam[day] || today
        credits = Blog::ContributorTerms.call(**credit)
        found = review_queries.review(period: Blog::Types::ReviewPeriodParam[period], on:, credits:)

        {
          review: found,
          note: review_note.call(found.period, found.from),
          on:,
          today:,
          credits:,
          choices: activity_queries.contributor_choices,
        }
      end
    end
  end
end
