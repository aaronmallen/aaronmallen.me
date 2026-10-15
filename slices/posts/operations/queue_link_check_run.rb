# frozen_string_literal: true

module Posts
  module Operations
    class QueueLinkCheckRun
      def call = Jobs::CheckPostLinks.perform_async
    end
  end
end
