# frozen_string_literal: true

module API
  module Endpoints
    class DropSprint < Endpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.widen(Serializers::Sprint::SCHEMA, dropped: Helpers::Schema::BOOLEAN).freeze

      include Deps[drop_sprint: "tasks.operations.drop_sprint"]

      def handle(id:)
        case drop_sprint.call(id)
          in Success(sprint) then Success(serialized(Serializers::Sprint, sprint).merge(dropped: true))
          in Failure(:started) then invalid(id: ["that sprint has already started"])
          in Failure(:not_found) then not_found(Helpers::Wording.missing("sprint", id))
          else failed(Helpers::Wording::UNSAVED)
        end
      end
    end
  end
end
