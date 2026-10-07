# frozen_string_literal: true

module API
  module Endpoints
    class ListInbox < Endpoint
      SCHEMA = { additionalProperties: false }.freeze
      REPLY = Schema.object({ inbox: Schema.list(Serializers::InboxRow.reference) }).freeze

      include Deps["repos.inbox_queries"]

      def handle = Success(inbox: serialized(Serializers::InboxRow, inbox_queries.unseen))
    end
  end
end
