# frozen_string_literal: true

module API
  module Endpoints
    class EndSession < Endpoint
      ENDED = "session %s already ended"
      SCHEMA = Helpers::Schema.by_id
      REPLY = Serializers::AgentSession.reference

      include Deps[end_session: "agents.operations.end_session"]

      def handle(id:)
        case end_session.call(id)
          in Success(session) then Success(serialized(Serializers::AgentSession, session))
          in Failure(:not_found) then missing("session", id)
          in Failure(:ended) then invalid(id: [format(ENDED, id)])
        end
      end
    end
  end
end
