# frozen_string_literal: true

module Agents
  module Operations
    class StartSession < Blog::Operation
      REFUSALS = { "agent_session_tasks_task_id_fkey" => [:task_ids, Blog::Contract::MISSING] }.freeze

      include Deps[
        agent_session_mutations: "repos.agent_session_mutations",
        contract: "contracts.session_contract",
        load_memory: "operations.load_memory",
        resolve_project: "operations.resolve_project",
      ]

      def call(params, at: Time.now)
        fields = step validate(params)

        step constrained(agent_session_mutations, REFUSALS) { Success(transaction { start(at:, **fields) }) }
      end

      private

      def start(at:, task_ids:, project: nil, **fields)
        project_id = step resolve_project.call(project:, repo: fields[:repo])
        id = agent_session_mutations.start(**fields, project_id:, task_ids:, started_at: at, last_seen_at: at)
        files = load_memory.call(project_id:, task_ids:)
        agent_session_mutations.record_index(id, files)
        [id, files]
      end
    end
  end
end
