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
          tag_queries: "tags.repos.tag_queries",
          task_rule_queries: "tasks.repos.task_rule_queries",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:rule]]

          result = save_task_rule.call(params, id:)

          settle(response, result, SAVED, routes.path(:admin_task_rules)) do |errors|
            invalid(response, id, params, errors)
          end
        end

        private

        def invalid(response, id, params, errors)
          editing = { errors:, id:, **UI::Views::TaskRules::Index.typed(params) }

          response.status = :unprocessable_content
          response.render(index_view, adding: BLANK, editing:, rules: task_rule_queries.all,
                                      projects: task_rule_queries.project_choices,
                                      tags: tag_queries.all_in(Index::PRIVATE, mail: false))
        end
      end
    end
  end
end
