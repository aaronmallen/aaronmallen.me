# frozen_string_literal: true

module API
  module Endpoints
    class ListInbox < Endpoint
      SCOPED = true
      SCHEMA = { additionalProperties: false }.freeze
      REPLY = Helpers::Schema.object({ inbox: Helpers::Schema.list(Serializers::InboxRow.reference) }).freeze

      include Deps["repos.inbox_queries"]

      def handle(scopes:)
        rows = inbox_queries.unseen
        rows = rows.reject { it.kind == :message } unless mail?(scopes)

        Success(inbox: serialized(Serializers::InboxRow, rows))
      end
    end
  end
end
