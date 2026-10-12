# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Menu < Action
        AHEAD = 4
        PRIVATE = Blog::Types::TagScope["private"]

        include Redirect
        include Deps[
          sprint_queries: "tasks.repos.sprint_queries",
          tag_queries: "tags.repos.tag_queries",
          task_queries: "tasks.repos.task_queries",
        ]

        def handle(request, response)
          task = task_queries.detailed(record_id(request)) || halt(404)
          today = Blog::TimeZone.today

          response.render(
            view,
            task:, today:, return_to: back_here(request), **return_to(request),
            sprints: sprint_queries.after(today + 1).first(AHEAD), tags: tag_queries.all_in(PRIVATE),
          )
        end
      end
    end
  end
end
