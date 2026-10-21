# frozen_string_literal: true

module Agents
  module Operations
    class RecordRead < Blog::Operation
      include Deps[agent_session_mutations: "repos.agent_session_mutations", record_loads: "operations.record_loads"]

      def call(session_id, memory_file_id, at: Time.now)
        return session_id if session_id.nil?

        transaction do
          step record_loads.call(session_id, [memory_file_id], at:)
          agent_session_mutations.record_read(session_id, memory_file_id, at)
        end
        session_id
      end
    end
  end
end
