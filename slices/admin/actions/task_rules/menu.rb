# frozen_string_literal: true

module Admin
  module Actions
    module TaskRules
      class Menu < Action
        include Deps[task_rule_queries: "tasks.repos.task_rule_queries"]

        def handle(request, response)
          response.render(view, rule: task_rule_queries.by_id(record_id(request)) || halt(404))
        end
      end
    end
  end
end
