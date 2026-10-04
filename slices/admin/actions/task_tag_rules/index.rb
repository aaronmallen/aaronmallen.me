# frozen_string_literal: true

module Admin
  module Actions
    module TaskTagRules
      class Index < Action
        include Deps[task_tag_rules: "tasks.queries.task_tag_rules"]

        def handle(_request, response)
          response.render(view, adding: UI::Views::TaskTagRules::Index::BLANK, editing: nil, rules: task_tag_rules.call)
        end
      end
    end
  end
end
