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
        },
      }.freeze

      REPLY = Serializers::Review.reference

      include Deps[review: "activity.queries.review"]

      def handle(period: Blog::Types::ReviewPeriod.values.first, day: nil)
        on = day ? Blog::TimeZone.parse_day(day) : Blog::TimeZone.today
        return invalid(day: [BAD_DAY]) unless on

        Success(serialized(Serializers::Review, review.call(period:, on:)))
      end
    end
  end
end
