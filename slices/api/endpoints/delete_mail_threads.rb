# frozen_string_literal: true

module API
  module Endpoints
    class DeleteMailThreads < BulkMailThreadEndpoint
      ACT = Blog::Types::MessageBulkAction["trash"]
      TRASHED = Helpers::Schema.object(
        { id: Helpers::Schema::INTEGER, subject: Helpers::Schema::STRING, trashed: Helpers::Schema::BOOLEAN },
      ).freeze
      REPLY = Helpers::Schema.object({ mail_threads: Helpers::Schema.list(TRASHED) }).freeze

      private

      def answered(threads) = threads.map { { id: it.id, subject: Helpers::Untrusted.call(it.subject), trashed: true } }
    end
  end
end
