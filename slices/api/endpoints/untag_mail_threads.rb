# frozen_string_literal: true

module API
  module Endpoints
    class UntagMailThreads < BulkMailThreadEndpoint
      ACT = Blog::Types::MessageBulkAction["untag"]
      SCHEMA = Helpers::Schema.widen(MailThreads::BULK, tag: MailThreads::TAG).freeze

      def handle(ids:, tag:) = acted(ids, tag:)
    end
  end
end
