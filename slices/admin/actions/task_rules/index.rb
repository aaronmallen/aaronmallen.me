# frozen_string_literal: true

module Admin
  module Actions
    module TaskRules
      class Index < Action
        include Deps[task_rule_queries: "tasks.repos.task_rule_queries"]

        def handle(_request, response)
          adding = UI::Views::TaskRules::Index::BLANK

          response.render(view, adding:, editing: nil, rules: task_rule_queries.all,
                                projects: task_rule_queries.project_choices)
        end
      end
    end
  end
end
