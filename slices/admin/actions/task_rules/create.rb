# frozen_string_literal: true

module Admin
  module Actions
    module TaskRules
      class Create < Action
        ADDED = "task_rules_page.toasts.added"

        include Deps[
          index_view: "ui.views.task_rules.index",
          save_task_rule: "tasks.operations.save_task_rule",
          task_rules: "tasks.queries.task_rules",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:rule]]

          case save_task_rule.call(params)
          in Success(_) then added(response)
          in Failure[:invalid, errors] then invalid(response, params, errors)
          else halt 500
          end
        end

        private

        def added(response)
          toast(response, ADDED)
          response.redirect_to(routes.path(:admin_task_rules))
        end

        def invalid(response, params, errors)
          adding = { errors:, **UI::Views::TaskRules::Index.typed(params) }

          response.status = 422
          response.render(index_view, adding:, editing: nil, rules: task_rules.call, projects: task_rules.projects)
        end
      end
    end
  end
end
