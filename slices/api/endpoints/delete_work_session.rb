# frozen_string_literal: true

module API
  module Endpoints
    class DeleteWorkSession < TaskEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Tasks::ID, session_id: Tasks::ID },
        required: %w[id session_id],
      }.freeze

      include Deps[delete_work_session: "tasks.operations.delete_work_session"]

      def handle(id:, session_id:)
        case delete_work_session.call(id, session_id)
        in Failure(:not_found) then not_found(Tasks.missing_session(id, session_id))
        in Failure[:invalid, errors] then rejected(errors)
        in result then settled(result, id)
        end
      end
    end
  end
end
