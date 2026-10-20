# frozen_string_literal: true

module Agents
  module Operations
    class RecordLoads < Blog::Operation
      include Deps[agent_session_mutations: "repos.agent_session_mutations", touch_session: "operations.touch_session"]

      def call(session_id, memory_file_ids, at: Time.now)
        return session_id if session_id.nil?

        step touch_session.call(session_id, at:)
        agent_session_mutations.record_loads(session_id, memory_file_ids.uniq)
        session_id
      end
    end
  end
end
