# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class RecordLinkEndpoint < Endpoint
      PLACED = %w[project task].freeze
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

      include Deps[
        project_queries: "projects.repos.project_queries",
        record_link_queries: "links.repos.record_link_queries",
      ]

      private

      def answered(kind, id, scopes)
        kinds = mail?(scopes) ? Serializers::Link::KINDS : Serializers::Link::UNMAILED

        Success(kind:, id:, links: linked(record_link_queries.for_record(kind, id), kinds))
      end

      def handled(fields, scopes)
        return super if mail?(scopes) || !fields.values_at(:kind, :other_kind).include?(Serializers::Link::MAIL_THREAD)

        Failure(Structs::Refusal.unmailed)
      end

      def public_in(fields)
        sides = { fields[:kind] => fields[:id], fields[:other_kind] => fields[:other_id] }
        return unless PLACED.all? { sides.key?(it) }

        on_board = task_queries.public_board_slugs([sides["task"]]).any?
        PUBLIC_TASK if on_board || project_queries.public_boards([sides["project"]]).any?
      end
    end
  end
end
