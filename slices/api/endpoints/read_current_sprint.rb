# frozen_string_literal: true

module API
  module Endpoints
    class ReadCurrentSprint < Endpoint
      SCHEMA = { additionalProperties: false }.freeze
      REPLY = Schema.widen(Serializers::Sprint::SCHEMA, tasks: Schema.list(Serializers::Task.reference)).freeze

      include Deps[current_sprint: "tasks.operations.current_sprint", task_queries: "tasks.repos.task_queries"]

      def handle
        case current_sprint.call
        in Success(sprint) then Success(serialized(Serializers::Sprint, sprint).merge(tasks: tasks(sprint)))
        else failed("could not open today's sprint")
        end
      end

      private

      def tasks(sprint)
        serialized(Serializers::Task, task_queries.in_sprint(sprint.id), sprint_on: sprint.sprint_date)
      end
    end
  end
end
