# frozen_string_literal: true

module Agents
  module Repos
    class AgentSessionQueries < Blog::DB::Repo
      CHILDREN = %i[agent_session_tasks agent_session_loads agent_session_reads memory_events artifact_versions].freeze
      DRAWER = [*CHILDREN, :agent_session_index_lines, { agent_session_searches: :agent_session_search_hits }].freeze
      LISTED = [*CHILDREN, :agent_session_searches].freeze
      IDLE_HOURS = 2
      TODAY_ARTIFACTS = 3

      def artifact_writes(session_id) = artifact_versions.where(session_id:).session_writes.to_a

      def by_id(id) = agent_sessions.combine(*DRAWER).by_pk(id).one

      def listed(page) = page.fill(agent_sessions.combine(*LISTED).latest_first.paged(page).to_a)

      def memory_changes(session_id) = memory_events.where(session_id:).session_changes.to_a

      def today_artifacts(now: Time.now)
        found = artifacts.where(id: written_ids(day_of(now))).latest_version_first.limit(TODAY_ARTIFACTS).to_a
        current = current_versions(found.map(&:id))

        found.map { { artifact: it, current: current.fetch(it.id) } }
      end

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

      def artifacts_written(day) = written_ids(day).distinct.count

      def by_agents(relation, day) = relation.where(created_at: day).exclude(agent: nil)

      def current_versions(ids)
        artifact_versions.current_listed.where(artifact_id: ids).to_a.to_h { [it.artifact_id, it] }
      end

      def day_of(now)
        today = Blog::TimeZone.local_date(now)

        Range.new(*Blog::TimeZone.day_bounds(today, today), true)
      end

      def written_ids(day) = by_agents(artifact_versions, day).dataset.unordered.select(:artifact_id)
    end
  end
end
