# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class Tag < TagAction
        DONE = "tagged"

        include Deps[tag_decision: "decisions.operations.tag_decision"]

        private

        def list_path = routes.path(:admin_decisions)

        def retag(id, tag) = tag_decision.call(id, tag)
      end
    end
  end
end
