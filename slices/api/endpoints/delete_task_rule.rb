# frozen_string_literal: true

module API
  module Endpoints
    class DeleteTaskRule < Endpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, deleted: Helpers::Schema::BOOLEAN }).freeze

      include Deps[delete_task_rule: "tasks.operations.delete_task_rule"]

      def handle(id:)
        case delete_task_rule.call(id)
          in Success(_) then Success(id:, deleted: true)
          in Failure(:not_found) then not_found(Helpers::Wording.missing("task rule", id))
          else failed("could not delete the rule")
        end
      end
    end
  end
end
