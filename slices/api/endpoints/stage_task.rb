# frozen_string_literal: true

module API
  module Endpoints
    class StageTask < TaskEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Tasks::ID,
          stage: { type: "string", enum: Blog::Types::TaskStage.values },
        },
        required: %w[id stage],
      }.freeze

      include Deps[stage_task: "tasks.operations.stage_task"]

      def handle(id:, stage:) = settled(stage_task.call(id, stage), id)
    end
  end
end
