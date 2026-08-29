# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Move < Action
        include Deps[move_project: "projects.operations.move_project"]

        def handle(request, response)
          case move_project.call(record_id(request), request.params[:direction])
          in Success(_) | Failure(:not_moved)
            response.redirect_to(routes.path(:admin_projects))
          in Failure(:not_found)
            halt 404
          else halt 500
          end
        end
      end
    end
  end
end
