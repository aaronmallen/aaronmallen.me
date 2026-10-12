# frozen_string_literal: true

module API
  module Endpoints
    class TagMailThreads < BulkMailThreadEndpoint
      ACT = Blog::Types::MessageBulkAction["tag"]
      SCHEMA = Helpers::Schema.widen(MailThreads::BULK, tag: MailThreads::TAG).freeze

      def handle(ids:, tag:) = acted(ids, tag:)
    end
  end
end
