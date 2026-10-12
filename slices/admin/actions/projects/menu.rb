# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Menu < Action
        PUBLIC = Blog::Types::TagScope["public"]

        include Deps[project_queries: "projects.repos.project_queries", tag_queries: "tags.repos.tag_queries"]

        def handle(request, response)
          project = project_queries.by_id(record_id(request)) || halt(404)

          response.render(view, project:, tags: tag_queries.all_in(PUBLIC), return_to: back_here(request))
        end
      end
    end
  end
end
