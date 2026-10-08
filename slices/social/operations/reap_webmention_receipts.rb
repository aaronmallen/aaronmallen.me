# frozen_string_literal: true

module Social
  module Operations
    class ReapWebmentionReceipts < Operation
      include Deps["settings", webmention_mutations: "repos.webmention_mutations"]

      def call(at: Time.now)
        window = settings.webmentions[:throttle_window_minutes] * Blog::Helpers::Figures::MINUTE

        webmention_mutations.delete_receipts_before(at - window)
      end
    end
  end
end
