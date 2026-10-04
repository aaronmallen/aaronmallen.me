# frozen_string_literal: true

module API
  module Endpoints
    class DropSprint < Endpoint
      SCHEMA = Schema.by_id
      REPLY = Schema.widen(Serializers::Sprint::SCHEMA, dropped: Schema::BOOLEAN).freeze

      include Deps[drop_sprint: "tasks.operations.drop_sprint"]

      def handle(id:)
        case drop_sprint.call(id)
        in Success(sprint) then Success(serialized(Serializers::Sprint, sprint).merge(dropped: true))
        in Failure(:started) then invalid(id: ["that sprint has already started"])
        in Failure(:not_found) then not_found(Sprints.missing(id))
        else failed(Wording::UNSAVED)
        end
      end
    end
  end
end
