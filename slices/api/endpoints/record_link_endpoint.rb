# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class RecordLinkEndpoint < Endpoint
      SCOPED = true
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

      def answered(kind, id, scopes)
        kinds = mail?(scopes) ? Serializers::Link::KINDS : Serializers::Link::UNMAILED

        Success(kind:, id:, links: linked(record_link_queries.for_record(kind, id), kinds))
      end

      def handled(fields, scopes)
        return super if mail?(scopes) || !fields.values_at(:kind, :other_kind).include?(Serializers::Link::MAIL_THREAD)

        Failure(Structs::Refusal.unmailed)
      end
    end
  end
end
