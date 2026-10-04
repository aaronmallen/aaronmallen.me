# frozen_string_literal: true

module API
  module Endpoints
    class DeleteTaskTagRule < Endpoint
      SCHEMA = Schema.by_id
      REPLY = Schema.object({ id: Schema::INTEGER, deleted: Schema::BOOLEAN }).freeze

      include Deps[delete_task_tag_rule: "tasks.operations.delete_task_tag_rule"]

      def handle(id:)
        case delete_task_tag_rule.call(id)
        in Success(_) then Success(id:, deleted: true)
        in Failure(:not_found) then not_found(TaskTagRules.missing(id))
        else failed("could not delete the rule")
        end
      end
    end
  end
end
