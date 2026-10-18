# frozen_string_literal: true

module Agents
  module Operations
    class CloseIdleSessions
      IDLE = 2 * 60 * 60

      include Deps[agent_session_mutations: "repos.agent_session_mutations"]

      def call(at: Time.now) = agent_session_mutations.close_idle(at - IDLE)
    end
  end
end
