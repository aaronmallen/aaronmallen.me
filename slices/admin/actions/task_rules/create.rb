# frozen_string_literal: true

module Admin
  module Actions
    module TaskRules
      class Create < Action
        ADDED = "task_rules_page.toasts.added"

        include Deps[
          index_view: "ui.views.task_rules.index",
          save_task_rule: "tasks.operations.save_task_rule",
          tag_queries: "tags.repos.tag_queries",
          task_rule_queries: "tasks.repos.task_rule_queries",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:rule]]

          settle(response, save_task_rule.call(params), ADDED, routes.path(:admin_task_rules)) do |errors|
            invalid(response, params, errors)
          end
        end

        private

        def invalid(response, params, errors)
          adding = { errors:, **UI::Views::TaskRules::Index.typed(params) }

          unprocessable(response, index_view, adding:, editing: nil, rules: task_rule_queries.all,
                                              projects: task_rule_queries.project_choices,
                                              tags: tag_queries.all_in(Index::PRIVATE, mail: false))
        end
      end
    end
  end
end
