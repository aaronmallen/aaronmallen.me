# auto_register: false
# frozen_string_literal: true

module Admin
  class UnlinkRecordAction < Action
    SCOPED = "record_links.toasts.scoped"
    UNLINKED = "record_links.toasts.unlinked"

    include Deps[unlink_records: "links.operations.unlink_records"]

    def handle(request, response)
      id = record_id(request)
      params = request.params

      result = unlink_records.call(self.class::KIND, id, params[:other_kind], params[:other_id])
      path = record_path(request, id)
      settle(response, result, self.class::UNLINKED, path) { toast_back(response, SCOPED, path) }
    end
  end
end
