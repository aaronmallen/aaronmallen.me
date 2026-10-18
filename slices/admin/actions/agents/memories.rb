# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      class Memories < Action
        include Deps[build_memories_page: "operations.build_memories_page"]

        def handle(request, response)
          response.render(view, **build_memories_page.call(**request.params.to_h.slice(:scope, :query, :repo)))
        end
      end
    end
  end
end
