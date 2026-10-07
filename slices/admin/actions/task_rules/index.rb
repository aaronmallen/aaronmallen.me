# frozen_string_literal: true

module Admin
  module Actions
    module TaskRules
      class Index < Action
        include Deps[task_rules: "tasks.queries.task_rules"]

        def handle(_request, response)
          adding = UI::Views::TaskRules::Index::BLANK

          response.render(view, adding:, editing: nil, rules: task_rules.call, projects: task_rules.projects)
        end
      end
    end
  end
end
