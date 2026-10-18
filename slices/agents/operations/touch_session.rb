# frozen_string_literal: true

module Agents
  module Operations
    class TouchSession < Blog::Operation
      CLOSED = "closed"

      include Deps[agent_session_mutations: "repos.agent_session_mutations"]

      def call(id, at: Time.now)
        step running(id, at) unless id.nil?
        id
      end

      private

      def running(id, at) = agent_session_mutations.touch(id, at).positive? ? Success(id) : invalid(:session_id, CLOSED)
    end
  end
end
