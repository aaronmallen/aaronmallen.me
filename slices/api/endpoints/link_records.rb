# frozen_string_literal: true

module API
  module Endpoints
    class LinkRecords < RecordLinkEndpoint
      PLACED = %w[project task].freeze
      SCHEMA = PAIR

      include Deps[link_records: "links.operations.link_records", project_queries: "projects.repos.project_queries"]

      def handle(kind:, id:, other_kind:, other_id:, scopes:)
        case link_records.call(kind, id, { other_kind:, other_id: })
          in Success(*) then answered(kind, id, scopes)
          in Failure(:not_found) then missing(RecordLinks.name(kind), id)
          in Failure[:invalid, errors] then rejected(errors, RecordLinks::COMPLAINTS)
          else failed(Helpers::Wording::UNSAVED)
        end
      end

      private

      def public_in(fields)
        sides = [fields.values_at(:kind, :id), fields.values_at(:other_kind, :other_id)].sort
        return unless sides.map(&:first) == PLACED

        PUBLIC_TASK if project_queries.public_boards([sides.first.last]).any?
      end
    end
  end
end
