# frozen_string_literal: true

module Record
  module Operations
    class QueueCommitImport < Blog::Operation
      include Deps["github.client"]

      def call
        step configured
        step(queued { Jobs::ImportCommits.perform_async })
      end

      private

      def configured = client.configured? ? Success() : Failure(:not_configured)
    end
  end
end
