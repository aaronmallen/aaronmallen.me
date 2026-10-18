# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Memories
        class Index < Action
          include Deps[build_memories_page: "operations.build_memories_page", view: "ui.views.agents.memories"]

          def handle(request, response)
            response.render(view, **build_memories_page.call(**request.params.to_h.slice(:scope, :query, :repo)))
          end
        end
      end
    end
  end
end
