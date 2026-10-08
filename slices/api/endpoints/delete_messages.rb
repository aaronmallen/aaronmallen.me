# frozen_string_literal: true

module API
  module Endpoints
    class DeleteMessages < BulkMessageEndpoint
      ACT = Blog::Types::MessageBulkAction["delete"]
      DELETED = Helpers::Schema.object(
        { id: Helpers::Schema::INTEGER, subject: Helpers::Schema::STRING, deleted: Helpers::Schema::BOOLEAN },
      ).freeze
      REPLY = Helpers::Schema.object({ messages: Helpers::Schema.list(DELETED) }).freeze

      private

      def answered(messages) = messages.map { { id: it.id, subject: it.subject, deleted: true } }
    end
  end
end
