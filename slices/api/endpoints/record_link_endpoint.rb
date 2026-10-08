# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class RecordLinkEndpoint < Endpoint
      PAIR = {
        additionalProperties: false,
        properties: {
          kind: RecordLinks::KIND,
          id: RecordLinks::ID,
          other_kind: RecordLinks::KIND,
          other_id: RecordLinks::ID,
        },
        required: %w[kind id other_kind other_id],
      }.freeze

      REPLY = Helpers::Schema.object(
        { kind: RecordLinks::KIND, id: Helpers::Schema::INTEGER, links: Serializers::Link::GROUPS },
      ).freeze

      include Deps[record_link_queries: "links.repos.record_link_queries"]

      private

      def answered(kind, id) = Success(kind:, id:, links: linked(kind, id))
    end
  end
end
