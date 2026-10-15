# frozen_string_literal: true

module API
  module Endpoints
    class ListLinks < RecordLinkEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { kind: RecordLinks::KIND, id: RecordLinks::ID },
        required: %w[kind id],
      }.freeze

      def handle(kind:, id:, scopes:) = answered(kind, id, scopes)
    end
  end
end
