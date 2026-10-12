# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class Untag < TagAction
        DONE = "untagged"

        include Deps[untag_decision: "decisions.operations.untag_decision"]

        private

        def list_path = routes.path(:admin_decisions)

        def retag(id, tag) = untag_decision.call(id, tag)
      end
    end
  end
end
