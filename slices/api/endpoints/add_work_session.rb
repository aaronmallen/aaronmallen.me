# frozen_string_literal: true

module API
  module Endpoints
    class AddWorkSession < TaskEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Tasks::TASK,
          started_at: Tasks.moment("when the session started"),
          ended_at: Tasks.moment("when the session ended"),
        },
        required: %w[id started_at ended_at],
      }.freeze

      include Deps[add_work_session: "tasks.operations.add_work_session"]

      def handle(id:, **times)
        case add_work_session.call(id, times)
          in Failure[:invalid, errors] then rejected(errors, Tasks::COMPLAINTS)
          in result then settled(result, id)
        end
      end
    end
  end
end
