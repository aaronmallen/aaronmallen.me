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

      REPLY = Schema.object(
        {
          kind: RecordLinks::KIND,
          id: Schema::INTEGER,
          links: Schema.object(
            {},
            optional: Blog::Types::RecordKind.values.to_h { [it.to_sym, Schema.list(Serializers::Link.reference)] },
          ),
        },
      ).freeze

      include Deps[record_links: "links.queries.record_links"]

      private

      def answered(kind, id)
        links = record_links.call(kind, id).transform_values { serialized(Serializers::Link, it) }

        Success(kind:, id:, links:)
      end
    end
  end
end
