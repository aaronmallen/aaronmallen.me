# frozen_string_literal: true

module API
  module Endpoints
    class ListInbox < Endpoint
      SCHEMA = { additionalProperties: false }.freeze
      REPLY = Schema.object({ inbox: Schema.list(Serializers::InboxRow.reference) }).freeze

      include Deps["queries.inbox"]

      def handle = Success(inbox: serialized(Serializers::InboxRow, inbox.call))
    end
  end
end
