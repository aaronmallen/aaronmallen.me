# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class ShowTag < Tags::Show
        include Deps[project_queries: "projects.repos.project_queries", view: "ui.views.tags.show"]

        private

        def project(request, response)
          id = project_queries.id_by_key(request.params[:key])
          id ? project_queries.by_id(id) : not_found(response)
        end
      end
    end
  end
end
