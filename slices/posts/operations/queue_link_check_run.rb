# frozen_string_literal: true

module Posts
  module Operations
    class QueueLinkCheckRun < Blog::Operation
      def call = step(queued { Jobs::CheckPostLinks.perform_async })
    end
  end
end
