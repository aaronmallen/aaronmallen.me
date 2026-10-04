# frozen_string_literal: true

module API
  module Endpoints
    class UnlinkRecords < RecordLinkEndpoint
      SCHEMA = PAIR

      include Deps[unlink_records: "links.operations.unlink_records"]

      def handle(kind:, id:, other_kind:, other_id:)
        case unlink_records.call(kind, id, other_kind, other_id)
        in Success(*) then answered(kind, id)
        in Failure(:not_found) then not_found(RecordLinks.unlinked(kind, id, other_kind, other_id))
        else failed(Wording::UNSAVED)
        end
      end
    end
  end
end
