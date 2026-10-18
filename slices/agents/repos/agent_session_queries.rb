# frozen_string_literal: true

module Agents
  module Repos
    class AgentSessionQueries < Blog::DB::Repo
      CHILDREN = %i[agent_session_tasks agent_session_loads memory_events artifact_versions].freeze

      def by_id(id) = agent_sessions.combine(*CHILDREN).by_pk(id).one

      def listed(page) = page.fill(agent_sessions.combine(*CHILDREN).latest_first.paged(page).to_a)
    end
  end
end
