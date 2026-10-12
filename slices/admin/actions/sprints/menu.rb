# frozen_string_literal: true

module Admin
  module Actions
    module Sprints
      class Menu < Action
        include Deps[sprint_queries: "tasks.repos.sprint_queries"]

        def handle(request, response)
          sprint = sprint_queries.by_id(record_id(request)) || halt(404)

          response.render(view, sprint:)
        end
      end
    end
  end
end
