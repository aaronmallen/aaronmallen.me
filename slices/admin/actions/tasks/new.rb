# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class New < Action
        include Redirect
        include Deps[project_queries: "projects.repos.project_queries"]

        def handle(request, response)
          params = request.params

          response.render(
            view,
            errors: Blog::Constants::EMPTY_HASH, origin: task_origin(request), projects: project_queries.live_by_name,
            values: { project: Blog::Types::Text[params[:project]], title: Blog::Types::Text[params[:title]] },
          )
        end
      end
    end
  end
end
