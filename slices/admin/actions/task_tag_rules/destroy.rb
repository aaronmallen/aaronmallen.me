# frozen_string_literal: true

module Admin
  module Actions
    module TaskTagRules
      class Destroy < Action
        DELETED = "task_tag_rules_page.toasts.deleted"

        include Deps[delete_task_tag_rule: "tasks.operations.delete_task_tag_rule"]

        def handle(request, response)
          result = delete_task_tag_rule.call(record_id(request))
          settle(response, result, DELETED, routes.path(:admin_task_tag_rules))
        end
      end
    end
  end
end
