# frozen_string_literal: true

module Admin
  module Actions
    module TaskTagRules
      class Destroy < Action
        DELETED = "task_tag_rules_page.toasts.deleted"

        include Deps[delete_task_tag_rule: "tasks.operations.delete_task_tag_rule"]

        def handle(request, response)
          case delete_task_tag_rule.call(record_id(request))
          in Success(_) then deleted(response)
          in Failure(:not_found) then halt 404
          else halt 500
          end
        end

        private

        def deleted(response)
          toast(response, DELETED)
          response.redirect_to(routes.path(:admin_task_tag_rules))
        end
      end
    end
  end
end
