# frozen_string_literal: true

module Agents
  module Repos
    class AgentSessionMutations < Blog::DB::Repo
      root :agent_sessions

      def add_tag(id, name) = agent_session_tags.tag(id, [name], tags, project_id: project_id(id))

      def by_id_for_update(id) = agent_sessions.by_pk(id).lock.one

      def close_idle(before) = agent_sessions.idle(before).update(ended_at: Sequel[:last_seen_at])

      def finish(id, at) = agent_sessions.by_pk(id).update(ended_at: at, last_seen_at: at)

      def record_index(id, files)
        rows = files.map do |file|
          {
            agent_session_id: id, memory_file_id: file.id, path: file.path, scope: file.scope,
            description: file.description, description_agent: file.description_agent,
            description_model: file.description_model, fact_count: file.facts.size,
          }
        end
        agent_session_index_lines.dataset.multi_insert(rows) unless rows.empty?
      end

      def record_loads(id, memory_file_ids)
        rows = memory_file_ids.map { { agent_session_id: id, memory_file_id: it } }
        agent_session_loads.dataset.insert_conflict.multi_insert(rows) unless rows.empty?
      end

      def record_read(id, memory_file_id, at)
        agent_session_reads.dataset.insert(agent_session_id: id, memory_file_id:, read_at: at)
      end

      def record_search(id, hits:, **fields)
        search_id = agent_session_searches.dataset.insert(agent_session_id: id, **fields)
        rows = hits.map do |fact|
          {
            agent_session_search_id: search_id, memory_fact_id: fact.id, memory_file_id: fact.memory_file_id,
            text: fact.text, path: fact.memory_file.path,
          }
        end
        agent_session_search_hits.dataset.multi_insert(rows) unless rows.empty?
      end

      def remove_tag(id, name) = agent_session_tags.untag(id, [name], tags)

      def start(task_ids:, **fields)
        id = agent_sessions.command(:create).call(fields).fetch(:id)
        agent_session_tasks.command(:create, result: :many).call(task_ids.map { { agent_session_id: id, task_id: it } })
        id
      end

      def touch(id, at) = agent_sessions.by_pk(id).running.update(last_seen_at: at)

      private

      def project_id(id) = agent_sessions.by_pk(id).pluck(:project_id).first
    end
  end
end
