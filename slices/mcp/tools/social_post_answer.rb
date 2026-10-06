# frozen_string_literal: true

module MCP
  module Tools
    module SocialPostAnswer
      include Dry::Monads[:result]

      COMPLAINTS = {
        "blank" => "is empty",
        Blog::Contract::CONTROL => Complaints::CONTROL,
        Blog::Contract::FORMAT => "needs a date and time, as 2026-10-01T09:30",
        Blog::Contract::SKIPPED => "falls in the hour the clocks skip in #{Blog::TimeZone::NAME}",
        "too_long" => "has a part over the limit for a network you picked",
        "unavailable" => "names a network that has no credentials",
        "unknown_mention" => "mentions someone who is not in the directory",
      }.freeze
      FAILED = "failed"
      RETRYING = "retrying"
      SENDING = "sending"
      SENT = "sent"
      TOO_LONG = "too_long"
      UNSAVED = "could not save the social post"
      WAITING = "waiting"

      private

      def complaint(errors, params, server_context)
        errors.map do |field, (token)|
          said = "#{field} #{COMPLAINTS.fetch(token, token)}"
          token == TOO_LONG ? "#{said}: #{overruns(params, server_context)}" : said
        end.join("; ")
      end

      def composed(result, id, params, server_context)
        case result
        in Success[_, social_post] then answer(social_post_entry(social_post, server_context))
        in Failure[:invalid, errors] then refuse(complaint(errors, params, server_context))
        in Failure(:already_posted) then refuse("social post #{id} has gone out, so nothing was saved")
        in Failure(:not_found) then refuse("no social post has the ID #{id}")
        else refuse(UNSAVED)
        end
      end

      def delivery(social_post, network)
        found = social_post.deliveries.find { it.network == network }
        return { network:, state: WAITING } unless found

        {
          network:,
          state: delivery_state(found, social_post.parts.length),
          url: found.remote_url,
          error: found.error,
          likes: found.like_count,
          reposts: found.repost_count,
          replies: found.reply_count,
        }
      end

      def delivery_state(found, parts)
        return FAILED if found.failed
        return SENT if found.remote_ids.to_a.length >= parts

        found.error ? RETRYING : SENDING
      end

      def lengths(social_post, server_context)
        measured = dep(:measure_parts, server_context).call(social_post.parts.map(&:body), social_post.targets.to_a)

        measured.map { |part| part.transform_values(&:counted) }
      end

      def overrun(length)
        return "part #{length.part} has too many bytes for #{length.network}" if length.count <= length.limit

        "part #{length.part} runs #{length.count} of #{length.limit} on #{length.network}"
      end

      def overruns(params, server_context)
        measured = dep(:measure_parts, server_context).call(*params.values_at(:parts, :targets))

        measured.flat_map(&:values).select(&:over).map { overrun(it) }.join(", ")
      end

      def social_post_entry(social_post, server_context)
        {
          id: social_post.id,
          status: social_post.status,
          post_id: social_post.post_id,
          posted_at: social_post.posted_at&.utc&.iso8601,
          created_at: social_post.created_at.utc.iso8601,
          parts: social_post.parts.map(&:body),
          lengths: lengths(social_post, server_context),
          deliveries: social_post.targets.map { delivery(social_post, it) },
        }
      end
    end
  end
end
