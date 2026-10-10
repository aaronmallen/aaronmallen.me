# frozen_string_literal: true

module Social
  module Operations
    class ReapWebmentionReceipts
      include Deps["settings", webmention_mutations: "repos.webmention_mutations"]

      def call(at: Time.now)
        webmention_mutations.delete_receipts_before(Blog::Throttle.new(settings.webmentions).since(at))
      end
    end
  end
end
