# frozen_string_literal: true

module Admin
  module Operations
    class BuildReviewPage
      include Deps[
        activity_queries: "activity.repos.activity_queries",
        contributor_terms: "contracts.contributor_terms_contract",
        review_queries: "activity.repos.review_queries",
        review_note_queries: "record.repos.review_note_queries",
      ]

      def call(period: nil, day: nil, today: Blog::TimeZone.today, **credit)
        on = Blog::Types::DateParam[day] || today
        credits = contributor_terms.call(credit).to_h
        found = review_queries.review(period: Blog::Types::ReviewPeriodParam[period], on:, credits:)

        {
          review: found,
          note: review_note_queries.note(found.period, found.from),
          on:,
          today:,
          credits:,
          choices: activity_queries.contributor_choices,
        }
      end
    end
  end
end
