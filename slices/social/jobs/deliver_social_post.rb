# frozen_string_literal: true

module Social
  module Jobs
    class DeliverSocialPost < Blog::Job
      class NetworkUnavailable < StandardError; end

      RETRIES = 5
      RETRYABLE = :send_failed

      include Deps[deliver_social_post: "operations.deliver_social_post"]

      sidekiq_options retry: RETRIES

      sidekiq_retries_exhausted do |job, _exception|
        new.give_up(*job["args"])
      end

      def give_up(social_post_id, network) = deliver_social_post.give_up(social_post_id, network)

      def perform(social_post_id, network)
        case deliver_social_post.call(social_post_id, network)
        in Failure(RETRYABLE) then raise NetworkUnavailable, "#{network} refused social post #{social_post_id}"
        else nil
        end
      end
    end
  end
end
