# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class RecordLinkEndpoint < Endpoint
      PLACED = %w[project task].freeze
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

      def answered(kind, id)
        Success(kind:, id:, links: linked(record_link_queries.for_record(kind, id), Serializers::Link::KINDS))
      end

      def handled(fields, scopes)
        sides = fields.values_at(:kind, :other_kind)
        scope, = GUARDED.except(*scopes).find { |_, kinds| kinds.intersect?(sides) }

        scope ? Failure(Structs::Refusal.unscoped(scope)) : super
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
