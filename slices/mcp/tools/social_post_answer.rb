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
      UNSAVED = "could not save the social post"
      WAITING = "waiting"

      private

      def complaint(errors)
        errors.map { |field, (token)| "#{field} #{COMPLAINTS.fetch(token, token)}" }.join("; ")
      end

      def composed(result, id)
        case result
        in Success[_, social_post] then answer(social_post_entry(social_post))
        in Failure[:invalid, errors] then refuse(complaint(errors))
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

      def social_post_entry(social_post)
        {
          id: social_post.id,
          status: social_post.status,
          post_id: social_post.post_id,
          posted_at: social_post.posted_at&.utc&.iso8601,
          created_at: social_post.created_at.utc.iso8601,
          parts: social_post.parts.map(&:body),
          deliveries: social_post.targets.map { delivery(social_post, it) },
        }
      end
    end
  end
end
