# frozen_string_literal: true

module API
  module Endpoints
    class ListSessions < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          page: Helpers::Paging::PAGE,
          project_id: Helpers::Schema::ID.merge(description: "only the sessions that ran in this project"),
        },
      }.freeze

      REPLY = Helpers::Schema.paged(
        { count: Helpers::Schema::INTEGER, sessions: Helpers::Schema.list(Serializers::AgentSession.reference) },
      ).freeze

      include Deps[agent_session_queries: "agents.repos.agent_session_queries"]

      def handle(page: 1, project_id: nil)
        found = agent_session_queries.listed(page_of(page), project_id:)

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
