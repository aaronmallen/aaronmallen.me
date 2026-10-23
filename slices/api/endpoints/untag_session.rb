# frozen_string_literal: true

module API
  module Endpoints
    class UntagSession < AgentTagging
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Helpers::Schema::ID, tag: UNTAG },
        required: %w[id tag],
      }.freeze

      REPLY = Serializers::AgentSession.reference

      include Deps[
        agent_session_queries: "agents.repos.agent_session_queries",
        untag_session: "agents.operations.untag_session",
      ]

      def handle(id:, tag:)
        untagged(:session, id, agent_session_queries.by_id(id), tag) { untag_session.call(id, it) }
      end
    end
  end
end
