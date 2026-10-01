# frozen_string_literal: true

module API
  module Endpoints
    class ReadCurrentSprint < Endpoint
      SCHEMA = { additionalProperties: false }.freeze

      include Deps[current_sprint: "tasks.operations.current_sprint", tasks_in_sprint: "tasks.queries.tasks_in_sprint"]

      def handle
        case current_sprint.call
        in Success(sprint) then Success(serialized(Serializers::Sprint, sprint).merge(tasks: tasks(sprint)))
        else failed("could not open today's sprint")
        end
      end

      private

      def tasks(sprint)
        serialized(Serializers::Task, tasks_in_sprint.call(sprint.id), sprint_on: sprint.sprint_date)
      end
    end
  end
end
