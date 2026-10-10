# frozen_string_literal: true

module Admin
  module Operations
    class BuildReviewPage
      ME = "me"
      OWNER = Blog::Types::ContributorKind["owner"]

      include Deps[
        activity_queries: "activity.repos.activity_queries",
        contributor_terms: "contracts.contributor_terms_contract",
        review_queries: "activity.repos.review_queries",
        review_note_queries: "record.repos.review_note_queries",
      ]

      def call(period: nil, day: nil, focus: nil, by: nil, today: Blog::TimeZone.today)
        on = Blog::Types::DateParam[day] || today
        credits = credits(by)
        found = review_queries.review(
          period: Blog::Types::ReviewPeriodParam[period], on:, focus: Blog::Types::DateParam[focus], credits:,
        )

        {
          review: found,
          note: review_note_queries.note(found.period, found.from),
          on:,
          today:,
          by: picked(credits),
          agents: activity_queries.contributor_choices.fetch(:agents),
        }
      end

      private

      def credits(by) = contributor_terms.call(by == ME ? { contributor: OWNER } : { agent: by }).to_h

      def picked(credits) = credits[:contributors].any? ? ME : credits[:agents].first
    end
  end
end
