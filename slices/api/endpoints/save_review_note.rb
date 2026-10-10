# frozen_string_literal: true

module API
  module Endpoints
    class SaveReviewNote < Endpoint
      COMPLAINTS = { body: { Blog::Contract::BLANK => "body needs a character that is not a space" } }.freeze
      UNSAVED = "could not save the review note"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          period: ReadReview::SCHEMA.dig(:properties, :period),
          day: { type: "string", description: "a day inside the period, as YYYY-MM-DD" },
          body: { type: "string", description: "the note, in Markdown; it replaces the period's note" },
        },
        required: %w[day body],
      }.freeze

      REPLY = Helpers::Schema.widen(
        Serializers::ReviewNote::SCHEMA,
        period: { type: "string", enum: Blog::Types::ReviewPeriod.values },
        from: Helpers::Schema::DAY,
        to: Helpers::Schema::DAY,
      ).freeze

      include Deps[
        review_range: "contracts.review_range_contract",
        save_review_note: "record.operations.save_review_note",
      ]

      def handle(day:, body:, period: Blog::Types::ReviewPeriod.values.first)
        on = Blog::TimeZone.parse_day(day)
        return invalid(day: [ReadReview::BAD_DAY]) unless on

        case save_review_note.call(body, period:, on:)
          in Success(note) then Success(answered(note))
          in Failure[:invalid, errors] then invalid(Helpers::Wording.complaints(errors, COMPLAINTS, named: true))
          else failed(UNSAVED)
        end
      end

      private

      def answered(note)
        review_range.call(period: note.period, on: note.starts_on).to_h => { from:, to: }

        { period: note.period, from: from.iso8601, to: to.iso8601, **serialized(Serializers::ReviewNote, note) }
      end
    end
  end
end
