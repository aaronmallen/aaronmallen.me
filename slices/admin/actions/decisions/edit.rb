# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class Edit < Action
        include Deps[
          build_decision_editor: "operations.build_decision_editor",
          decision_by_id: "decisions.queries.by_id",
        ]

        def handle(request, response)
          decision = decision_by_id.call(record_id(request))
          not_found(response) unless decision

          response.render(view, **build_decision_editor.call(decision:))
        end
      end
    end
  end
end
