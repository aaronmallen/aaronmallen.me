# frozen_string_literal: true

module Admin
  module Operations
    class BuildReviewPage
      include Deps[review: "activity.queries.review"]

      def call(period: nil, day: nil, today: Blog::TimeZone.today)
        on = Blog::Types::DateParam[day] || today

        { review: review.call(period: Blog::Types::ReviewPeriodParam[period], on:), on:, today: }
      end
    end
  end
end
