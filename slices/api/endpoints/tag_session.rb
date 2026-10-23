# frozen_string_literal: true

module API
  module Endpoints
    class TagSession < AgentTagging
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Helpers::Schema::ID, tag: TAG },
        required: %w[id tag],
      }.freeze

      REPLY = Serializers::AgentSession.reference

      include Deps[tag_session: "agents.operations.tag_session"]

      def handle(id:, tag:) = tagged(:session, id, tag) { tag_session.call(id, it) }
    end
  end
end
