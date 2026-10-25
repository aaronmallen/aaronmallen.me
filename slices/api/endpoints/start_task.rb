# frozen_string_literal: true

module API
  module Endpoints
    class StartTask < TaskEndpoint
      SCHEMA = Tasks::BY_ID
      SHOWN = %i[sprint_on].freeze
      SHOWS_TASKS = true

      REPLY = Helpers::Schema.object(BRIEF.merge(Serializers::Task::SCHEMA[:properties].slice(*SHOWN))).freeze

      include Deps[start_task: "tasks.operations.start_task"]

      def handle(id:) = settled(start_task.call(id), id, SHOWN)
    end
  end
end
