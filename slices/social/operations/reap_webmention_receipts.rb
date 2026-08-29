# frozen_string_literal: true

module Social
  module Operations
    class ReapWebmentionReceipts < Blog::Operation
      MINUTE = 60

      include Deps["settings", webmention_repo: "repos.webmention_repo"]

      def call(at: Time.now)
        webmention_repo.delete_receipts_before(at - (settings.webmentions[:throttle_window_minutes] * MINUTE))
      end
    end
  end
end
