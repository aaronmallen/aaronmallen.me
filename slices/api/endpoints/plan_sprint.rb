# frozen_string_literal: true

module API
  module Endpoints
    class PlanSprint < Endpoint
      SCHEMA = { additionalProperties: false, properties: { sprint_on: Sprints::DAY }, required: ["sprint_on"] }.freeze
      REPLY = Serializers::Sprint.reference

      include Deps[plan_sprint: "tasks.operations.plan_sprint"]

      def handle(sprint_on:)
        case plan_sprint.call(sprint_on)
          in Success(sprint) then Success(serialized(Serializers::Sprint, sprint))
          in Failure[:planned, day] then refused("a sprint already exists for #{day.iso8601}")
          in Failure(:past) then refused("plan a sprint for a day after today")
          in Failure(:invalid) then refused("pick a day first, such as 2026-01-01")
          else failed(Helpers::Wording::UNSAVED)
        end
      end

      private

      def refused(message) = invalid(sprint_on: [message])
    end
  end
end
