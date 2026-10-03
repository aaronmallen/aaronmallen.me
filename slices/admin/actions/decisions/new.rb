# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class New < Action
        include Deps[build_decision_editor: "operations.build_decision_editor"]

        def handle(_request, response)
          response.render(view, **build_decision_editor.call)
        end
      end
    end
  end
end
