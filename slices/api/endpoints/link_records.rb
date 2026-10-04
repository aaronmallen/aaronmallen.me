# frozen_string_literal: true

module API
  module Endpoints
    class LinkRecords < RecordLinkEndpoint
      SCHEMA = PAIR

      include Deps[link_records: "links.operations.link_records"]

      def handle(kind:, id:, other_kind:, other_id:)
        case link_records.call(kind, id, { other_kind:, other_id: })
        in Success(*) then answered(kind, id)
        in Failure(:not_found) then not_found(RecordLinks.missing(kind, id))
        in Failure[:invalid, errors] then rejected(errors)
        else failed(RecordLinks::UNSAVED)
        end
      end

      private

      def rejected(errors)
        complaints = RecordLinks.complaints(errors)

        Failure(Refusal.invalid(complaints, message: RecordLinks.summary(complaints)))
      end
    end
  end
end
