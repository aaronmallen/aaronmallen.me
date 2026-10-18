# frozen_string_literal: true

module Agents
  module Repos
    class AgentSessionMutations < Blog::DB::Repo
      root :agent_sessions

      def by_id_for_update(id) = agent_sessions.by_pk(id).lock.one

      def close_idle(before) = agent_sessions.idle(before).update(ended_at: Sequel[:last_seen_at])

      def finish(id, at) = agent_sessions.by_pk(id).update(ended_at: at, last_seen_at: at)

      def record_loads(id, memory_file_ids)
        agent_session_loads.multi_insert(memory_file_ids.map { { agent_session_id: id, memory_file_id: it } })
      end

      def start(task_ids:, **fields)
        id = agent_sessions.command(:create).call(fields).fetch(:id)
        agent_session_tasks.command(:create, result: :many).call(task_ids.map { { agent_session_id: id, task_id: it } })
        id
      end

      def touch(id, at) = agent_sessions.by_pk(id).running.update(last_seen_at: at)
    end
  end
end
