# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class SocialPostEndpoint < Endpoint
      COMPLAINTS = {
        "blank" => "is empty",
        Blog::Contract::CONTROL => Wording::CONTROL,
        Blog::Contract::FORMAT => "needs a date and time, as 2026-10-01T09:30",
        Blog::Contract::SKIPPED => "falls in the hour the clocks skip in #{Blog::TimeZone::NAME}",
        "too_long" => "has a part over the limit for a network you picked",
        "unavailable" => "names a network that has no credentials",
        "unknown_mention" => "mentions someone who is not in the directory",
      }.freeze
      GONE = "social post %s has gone out, so nothing was %s"
      REPLY = Serializers::SocialPost::SCHEMA.merge(
        required: [*Serializers::SocialPost::SCHEMA.fetch(:required), "lengths"],
      ).freeze
      TARGETS = {
        type: "array",
        items: { type: "string", enum: Blog::Types::NetworkName.values },
        description: "the networks it goes out to",
      }.freeze
      TOO_LONG = "too_long"
      UNSAVED = "could not save the social post"

      include Deps[
        measure_parts: "social.operations.measure_parts",
        social_post_queries: "social.repos.social_post_queries",
      ]

      private

      def answered(social_post) = serialized(Serializers::SocialPost, social_post, measure_parts:)

      def composed(result, id, params)
        case result
          in Success[_, social_post] then Success(answered(social_post))
          in Failure[:invalid, errors] then invalid(refusals(errors, params))
          in Failure(:already_posted) then gone(id, "saved")
          in Failure(:not_found) then not_found(Wording.missing("social post", id))
          else failed(UNSAVED)
        end
      end

      def gone(id, outcome) = invalid(id: [format(GONE, id, outcome)])

      def overrun(length)
        return "part #{length.part} has too many bytes for #{length.network}" if length.count <= length.limit

        "part #{length.part} runs #{length.count} of #{length.limit} on #{length.network}"
      end

      def overruns(params)
        measured = measure_parts.call(*params.values_at(:parts, :targets))

        measured.flat_map(&:values).select(&:over).map { overrun(it) }.join(", ")
      end

      def refusals(errors, params)
        errors.to_h do |field, (token)|
          said = "#{field} #{COMPLAINTS.fetch(token, token)}"
          [field, [token == TOO_LONG ? "#{said}: #{overruns(params)}" : said]]
        end
      end
    end
  end
end
