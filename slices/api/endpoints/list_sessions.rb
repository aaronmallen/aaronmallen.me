# frozen_string_literal: true

module API
  module Endpoints
    class ListSessions < Endpoint
      SCHEMA = { additionalProperties: false, properties: { page: Helpers::Paging::PAGE } }.freeze

      REPLY = Helpers::Schema.paged(
        { count: Helpers::Schema::INTEGER, sessions: Helpers::Schema.list(Serializers::AgentSession.reference) },
      ).freeze

      include Deps[agent_session_queries: "agents.repos.agent_session_queries"]

      def handle(page: 1)
        found = agent_session_queries.listed(page_of(page))

        Success(
          {
            count: found.rows.length,
            sessions: serialized(Serializers::AgentSession, found.rows),
            **Helpers::Paging.fields(found),
          },
        )
      end
    end
  end
end
