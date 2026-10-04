# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class CreateWork < Action
        ADDED = "projects_page.toasts.role_added"
        WORK = Blog::Types::ProjectFilter["work"]

        include Deps[
          add_work_entry: "projects.operations.add_work_entry",
          build_projects_page: "operations.build_projects_page",
          index_view: "ui.views.projects.index",
          log_work_view: "ui.views.projects.log_work",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:work_entry]]
          back = auth_session(request).admin_return_path(request.params[:return_to])

          case add_work_entry.call(params)
          in Success(_)
            toast(response, ADDED)
            response.redirect_to(back || routes.path(:admin_projects, filter: WORK))
          in Failure[:invalid, errors] then invalid(response, params, errors, back)
          else halt 500
          end
        end

        private

        def invalid(response, params, errors, back)
          response.status = 422
          return response.render(index_view, **build_projects_page.call(filter: WORK, params:, errors:)) unless back

          values = Operations::BuildProjectsPage::FIELDS.to_h { [it, Blog::Types::Text[params[it]]] }
          response.render(log_work_view, errors:, values:, return_to: back)
        end
      end
    end
  end
end
