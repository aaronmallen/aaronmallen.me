# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      class UntagSession < TagAction
        DONE = "untagged"

        include Deps[untag_session: "agents.operations.untag_session"]

        private

        def list_path = routes.path(:admin_agent_sessions)

        def retag(id, tag) = untag_session.call(id, tag)
      end
    end
  end
end
