# frozen_string_literal: true

module API
  module Endpoints
    class SaveReviewNote < Endpoint
      COMPLAINTS = {
        Blog::Contract::BLANK => "body needs a character that is not a space",
        Blog::Contract::CONTROL => "body holds a control character",
      }.freeze
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

      REPLY = Schema.widen(
        Serializers::ReviewNote::SCHEMA,
        period: { type: "string", enum: Blog::Types::ReviewPeriod.values },
        from: Schema::DAY,
        to: Schema::DAY,
      ).freeze

      include Deps[save_review_note: "record.operations.save_review_note"]

      def handle(day:, body:, period: Blog::Types::ReviewPeriod.values.first)
        on = Blog::TimeZone.parse_day(day)
        return invalid(day: [ReadReview::BAD_DAY]) unless on

        case save_review_note.call(body, period:, on:)
          in Success(note) then Success(answered(note))
          in Failure[:invalid, errors] then invalid(reasons(errors))
          else failed(UNSAVED)
        end
      end

      private

      def answered(note)
        from, to = Blog::ReviewRange.call(note.period, note.starts_on)

        { period: note.period, from: from.iso8601, to: to.iso8601, **serialized(Serializers::ReviewNote, note) }
      end

      def reasons(errors)
        errors.to_h { |field, tokens| [field, tokens.map { COMPLAINTS.fetch(it) { "#{field} #{it}" } }] }
      end
    end
  end
end
