# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      class TagSession < TagAction
        DONE = "tagged"

        include Deps[tag_session: "agents.operations.tag_session"]

        private

        def list_path = routes.path(:admin_agent_sessions)

        def retag(id, tag) = tag_session.call(id, tag)
      end
    end
  end
end
