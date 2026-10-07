# frozen_string_literal: true

module Posts
  module Operations
    class QueueFollowUp
      SEND_WEBMENTIONS = Blog::Types::PostFollowUp["send_webmentions"]
      SYNDICATE_POST = Blog::Types::PostFollowUp["syndicate_post"]

      include Deps[honeybadger: "honeybadger.agent", post_mutations: "repos.post_mutations"]

      def call(post_id, follow_up, at: Time.now)
        queue(post_id, follow_up, at)
      rescue RedisClient::Error => e
        honeybadger.notify(e)
        post_mutations.hold_follow_up(post_id:, follow_up:, requested_at: at)
      end

      def queue(post_id, follow_up, at)
        case follow_up
        when SYNDICATE_POST then Social::Jobs::SyndicatePost.once_published(post_id, at)
        when SEND_WEBMENTIONS then Social::Jobs::SendWebmentions.once_saved(post_id)
        end
      end
    end
  end
end
