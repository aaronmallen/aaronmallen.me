# frozen_string_literal: true

module API
  module Endpoints
    class DropSprint < Endpoint
      SCHEMA = { additionalProperties: false, properties: { id: Sprints::ID }, required: ["id"] }.freeze

      include Deps[drop_sprint: "tasks.operations.drop_sprint"]

      def handle(id:)
        case drop_sprint.call(id)
        in Success(sprint) then Success(serialized(Serializers::Sprint, sprint).merge(dropped: true))
        in Failure(:started) then invalid(id: ["that sprint has already started"])
        in Failure(:not_found) then not_found(Sprints.missing(id))
        else failed(Sprints::UNSAVED)
        end
      end
    end
  end
end
