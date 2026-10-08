# frozen_string_literal: true

module API
  module Endpoints
    class ReadReview < Endpoint
      BAD_DAY = "give the day as a date, such as 2026-01-01"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          period: {
            type: "string",
            enum: Blog::Types::ReviewPeriod.values,
            description: "week, from Monday to Sunday, or the calendar month; week when left out",
          },
          day: { type: "string", description: "a day inside the period, as YYYY-MM-DD; today when left out" },
          **Schema::CREDITS,
        },
      }.freeze

      REPLY = Serializers::Review.reference

      include Deps[
        contributor_terms: "contracts.contributor_terms_contract",
        review_note_queries: "record.repos.review_note_queries",
        review_queries: "activity.repos.review_queries",
      ]

      def handle(period: Blog::Types::ReviewPeriod.values.first, day: nil, **credited)
        on = day ? Blog::TimeZone.parse_day(day) : Blog::TimeZone.today
        return invalid(day: [BAD_DAY]) unless on

        found = review_queries.review(period:, on:, credits: contributor_terms.call(credited).to_h)

        Success(serialized(Serializers::Review, found, note: review_note_queries.note(found.period, found.from)))
      end
    end
  end
end
