# frozen_string_literal: true

module Admin
  module Operations
    class BuildReviewPage
      include Deps[review: "activity.queries.review", review_note: "record.queries.review_note"]

      def call(period: nil, day: nil, today: Blog::TimeZone.today)
        on = Blog::Types::DateParam[day] || today
        found = review.call(period: Blog::Types::ReviewPeriodParam[period], on:)

        { review: found, note: review_note.call(found.to), on:, today: }
      end
    end
  end
end
