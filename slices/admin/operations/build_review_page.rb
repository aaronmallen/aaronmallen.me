# frozen_string_literal: true

module Admin
  module Operations
    class BuildReviewPage
      include Deps[
        contributor_choices: "activity.queries.contributor_choices",
        review: "activity.queries.review",
        review_note: "record.queries.review_note",
      ]

      def call(period: nil, day: nil, today: Blog::TimeZone.today, **credit)
        on = Blog::Types::DateParam[day] || today
        credits = Blog::ContributorTerms.call(**credit)
        found = review.call(period: Blog::Types::ReviewPeriodParam[period], on:, credits:)

        {
          review: found,
          note: review_note.call(found.period, found.from),
          on:,
          today:,
          credits:,
          choices: contributor_choices.call,
        }
      end
    end
  end
end
