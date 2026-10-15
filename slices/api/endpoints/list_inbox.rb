# frozen_string_literal: true

module API
  module Endpoints
    class ListInbox < Endpoint
      SCOPED = true
      SCHEMA = { additionalProperties: false }.freeze
      REPLY = Helpers::Schema.object({ inbox: Helpers::Schema.list(Serializers::InboxRow.reference) }).freeze

      include Deps["repos.inbox_queries"]

      def handle(scopes:)
        Success(inbox: serialized(Serializers::InboxRow, inbox_queries.unseen(mail: mail?(scopes))))
      end
    end
  end
end
