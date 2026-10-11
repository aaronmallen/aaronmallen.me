# auto_register: false
# frozen_string_literal: true

module Admin
  class UnlinkRecordAction < Action
    UNLINKED = "record_links.toasts.unlinked"

    include Deps[unlink_records: "links.operations.unlink_records"]

    def handle(request, response)
      id = record_id(request)
      params = request.params

      result = unlink_records.call(self.class::KIND, id, params[:other_kind], params[:other_id])
      settle(response, result, self.class::UNLINKED, record_path(request, id))
    end
  end
end
