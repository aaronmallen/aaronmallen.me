# frozen_string_literal: true

module Mail
  module Jobs
    class BackfillGmail < Blog::Job
      include Deps[sync_gmail: "operations.sync_gmail"]

      sidekiq_options retry: 3

      def perform(address, page_token = nil)
        case sync_gmail.backfill(address, page_token)
          in Success(nil) then nil
          in Success(following) then self.class.perform_async(address, following)
          in Failure(_, message) then raise Error, message
        end
      end
    end
  end
end
