# frozen_string_literal: true

module Admin
  module Actions
    module TaskRules
      class Update < Action
        BLANK = UI::Views::TaskRules::Index::BLANK
        SAVED = "task_rules_page.toasts.saved"

        include Deps[
          index_view: "ui.views.task_rules.index",
          save_task_rule: "tasks.operations.save_task_rule",
          task_rules: "tasks.queries.task_rules",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:rule]]

          result = save_task_rule.call(params, id:)

          case result
          in Failure[:invalid, errors] then invalid(response, id, params, errors)
          else settle(response, result, SAVED, routes.path(:admin_task_rules))
          end
        end

        private

        def invalid(response, id, params, errors)
          editing = { errors:, id:, **UI::Views::TaskRules::Index.typed(params) }

          response.status = 422
          response.render(index_view, adding: BLANK, editing:, rules: task_rules.call, projects: task_rules.projects)
        end
      end
    end
  end
end
