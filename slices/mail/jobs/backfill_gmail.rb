# frozen_string_literal: true

module Mail
  module Jobs
    class BackfillGmail < Blog::Job
      PACE = 30
      RATE_LIMIT_WAIT = 120

      include Deps[sync_gmail: "operations.sync_gmail"]

      sidekiq_options retry: 3

      def perform(address, page_token = nil)
        case sync_gmail.backfill(address, page_token)
          in Success(nil) then nil
          in Success(following) then self.class.perform_in(PACE, address, following)
          in Failure(:gmail_rate_limited, _) then self.class.perform_in(RATE_LIMIT_WAIT, address, page_token)
          in Failure(_, message) then raise Error, message
        end
      end
    end
  end
end
