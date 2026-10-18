# frozen_string_literal: true

module Agents
  module Repos
    class AgentSessionQueries < Blog::DB::Repo
      CHILDREN = %i[agent_session_tasks agent_session_loads memory_events artifact_versions].freeze

      def artifact_writes(session_id) = artifact_versions.where(session_id:).session_writes.to_a

      def by_id(id) = agent_sessions.combine(*CHILDREN).by_pk(id).one

      def listed(page) = page.fill(agent_sessions.combine(*CHILDREN).latest_first.paged(page).to_a)

      def memory_changes(session_id) = memory_events.where(session_id:).session_changes.to_a

      def today_counts(now: Time.now)
        day = day_of(now)

        {
          sessions: agent_sessions.where(started_at: day).count,
          running: agent_sessions.running.count,
          memory_changes: by_agents(memory_events, day).count,
          artifacts: artifacts_written(day),
        }
      end

      private

      def artifacts_written(day)
        by_agents(artifact_versions, day).dataset.unordered.distinct.select(:artifact_id).count
      end

      def by_agents(relation, day) = relation.where(created_at: day).exclude(agent: nil)

      def day_of(now)
        today = Blog::TimeZone.today(now)

        Range.new(*Blog::TimeZone.day_bounds(today, today), true)
      end
    end
  end
end
