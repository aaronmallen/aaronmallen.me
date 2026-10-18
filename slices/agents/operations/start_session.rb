# frozen_string_literal: true

module Agents
  module Operations
    class StartSession < Blog::Operation
      REFUSALS = { "agent_session_tasks_task_id_fkey" => [:task_ids, Blog::Contract::MISSING] }.freeze

      include Deps[
        agent_session_mutations: "repos.agent_session_mutations",
        contract: "contracts.session_contract",
        load_memory: "operations.load_memory",
      ]

      def call(params, at: Time.now)
        fields = step validate(params)

        step constrained(agent_session_mutations, REFUSALS) { Success(transaction { start(at:, **fields) }) }
      end

      private

      def start(at:, task_ids:, **fields)
        id = agent_session_mutations.start(**fields, task_ids:, started_at: at, last_seen_at: at)
        files = load_memory.call(repo: fields[:repo], task_ids:)
        agent_session_mutations.record_loads(id, files.map(&:id))
        [id, files]
      end
    end
  end
end
