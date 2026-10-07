# frozen_string_literal: true

module API
  module Endpoints
    class UpdateWorkSession < TaskEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Tasks::ID,
          session_id: Tasks::ID,
          started_at: Tasks.moment("when the session started"),
          ended_at: Tasks.moment("when the session ended; a finished session needs it, the running one takes none"),
        },
        required: %w[id session_id started_at],
      }.freeze

      include Deps[edit_work_session: "tasks.operations.edit_work_session"]

      def handle(id:, session_id:, **times)
        case edit_work_session.call(id, session_id, times)
          in Failure(:not_found) then not_found(Tasks.missing_session(id, session_id))
          in Failure[:invalid, errors] then rejected(errors, Tasks::COMPLAINTS)
          in result then settled(result, id)
        end
      end
    end
  end
end
