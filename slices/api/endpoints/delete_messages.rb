# frozen_string_literal: true

module API
  module Endpoints
    class DeleteMessages < BulkMessageEndpoint
      ACT = Blog::Types::MessageBulkAction["delete"]
      DELETED = Schema.object({ id: Schema::INTEGER, subject: Schema::STRING, deleted: Schema::BOOLEAN }).freeze
      REPLY = Schema.object({ messages: Schema.list(DELETED) }).freeze

      private

      def answered(messages) = messages.map { { id: it.id, subject: it.subject, deleted: true } }
    end
  end
end
