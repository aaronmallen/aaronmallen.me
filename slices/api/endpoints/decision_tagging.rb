# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class DecisionTagging < DecisionEndpoint
      include Deps[edit_decision: "decisions.operations.edit_decision"]

      private

      def retag(decision, tags)
        params = { title: decision.title, problem: decision.problem, tags: Decisions.tag_list(tags) }

        settled(edit_decision.call(decision.id, params), decision.id)
      end
    end
  end
end
