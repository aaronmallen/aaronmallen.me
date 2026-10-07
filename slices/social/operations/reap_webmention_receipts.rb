# frozen_string_literal: true

module Social
  module Operations
    class ReapWebmentionReceipts < Operation
      include Deps["settings", webmention_repo: "repos.webmention_repo"]

      def call(at: Time.now)
        window = settings.webmentions[:throttle_window_minutes] * Blog::Figures::MINUTE

        webmention_repo.delete_receipts_before(at - window)
      end
    end
  end
end
