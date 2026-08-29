# frozen_string_literal: true

module Social
  module Jobs
    class SendWebmentions < Blog::Job
      class EndpointUnreachable < StandardError; end

      RETRYABLE = :send_failed

      include Deps[send_webmentions: "operations.send_webmentions"]

      sidekiq_options retry: 5

      def self.once_saved(post_id) = perform_async(post_id)

      def perform(post_id)
        case send_webmentions.call(post_id)
        in Failure(RETRYABLE) then raise EndpointUnreachable
        else nil
        end
      end
    end
  end
end
