# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class UnlinkRecord < Action
        KIND = Blog::Types::RecordKind["decision"]
        UNLINKED = "decisions_page.toasts.record_unlinked"

        include PageForm
        include Deps[unlink_records: "links.operations.unlink_records"]

        def handle(request, response)
          params = request.params

          case unlink_records.call(KIND, record_id(request), params[:other_kind], params[:other_id])
          in Success(_) then to_decision(request, response, UNLINKED)
          in Failure(:not_found) then halt 404
          else halt 500
          end
        end
      end
    end
  end
end
