# frozen_string_literal: true

module Mail
  module Jobs
    class BackfillGmail < Blog::Job
      PACE = 30
      RATE_LIMIT_WAIT = 120

      include Deps[gmail_backfills: "repos.gmail_backfills", sync_gmail: "operations.sync_gmail"]

      def perform(address, page_token = nil)
        gmail_backfills.hold(address, page_token)
        case sync_gmail.backfill(address, page_token)
          in Success(nil) then gmail_backfills.hold(address, nil, at: nil)
          in Success(following) then queue_next(address, following)
          in Failure(:gmail_rate_limited, _) then self.class.perform_in(RATE_LIMIT_WAIT, address, page_token)
          in Failure(_, message) then raise Error, message
        end
      end

      private

      def queue_next(address, page_token)
        gmail_backfills.hold(address, page_token)
        self.class.perform_in(PACE, address, page_token)
      end
    end
  end
end
