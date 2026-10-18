# frozen_string_literal: true

module Agents
  module Operations
    class EndSession < Blog::Operation
      include Deps[
        agent_session_mutations: "repos.agent_session_mutations",
        agent_session_queries: "repos.agent_session_queries",
      ]

      def call(id, at: Time.now)
        transaction do
          step running(step(found(agent_session_mutations.by_id_for_update(id))))
          agent_session_mutations.finish(id, at)
        end

        agent_session_queries.by_id(id)
      end

      private

      def running(session) = session.ended_at ? Failure(:ended) : Success(session)
    end
  end
end
