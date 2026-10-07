# frozen_string_literal: true

module API
  module Endpoints
    class LinkRecords < RecordLinkEndpoint
      SCHEMA = PAIR

      include Deps[link_records: "links.operations.link_records"]

      def handle(kind:, id:, other_kind:, other_id:)
        case link_records.call(kind, id, { other_kind:, other_id: })
          in Success(*) then answered(kind, id)
          in Failure(:not_found) then not_found(Wording.missing(RecordLinks.name(kind), id))
          in Failure[:invalid, errors] then rejected(errors, RecordLinks::COMPLAINTS)
          else failed(Wording::UNSAVED)
        end
      end
    end
  end
end
