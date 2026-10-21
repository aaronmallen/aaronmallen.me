# frozen_string_literal: true

module Agents
  module Relations
    class AgentSessions < Blog::DB::Relation
      schema :agent_sessions, infer: true do
        associations do
          has_many :agent_session_tasks
          has_many :agent_session_loads, view: :with_paths
          has_many :agent_session_index_lines, view: :in_order
          has_many :memory_events, foreign_key: :session_id, view: :session_listed
          has_many :artifact_versions, foreign_key: :session_id, view: :session_listed
        end
      end

      def idle(before) = running.where(Sequel[:last_seen_at] < before)

      def latest_first = order(self[:started_at].desc, self[:id].desc)

      def running = where(ended_at: nil)
    end
  end
end
