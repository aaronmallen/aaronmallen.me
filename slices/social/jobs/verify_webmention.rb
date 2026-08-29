# frozen_string_literal: true

module Social
  module Jobs
    class VerifyWebmention < Blog::Job
      class SourceUnreachable < StandardError; end

      RETRYABLE = :fetch_failed

      include Deps[verify_webmention: "operations.verify_webmention"]

      sidekiq_options retry: 5

      def perform(source, target, post_id)
        case verify_webmention.call(source:, target:, post_id:)
        in Failure(RETRYABLE) then raise SourceUnreachable
        else nil
        end
      end
    end
  end
end
