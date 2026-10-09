# frozen_string_literal: true

module API
  module Endpoints
    class UntagMessages < BulkMessageEndpoint
      ACT = Blog::Types::MessageBulkAction["untag"]
      SCHEMA = Helpers::Schema.widen(Messages::BULK, tag: Messages::TAG).freeze

      def handle(ids:, tag:) = acted(ids, tag:)
    end
  end
end
