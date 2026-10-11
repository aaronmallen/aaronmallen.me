# auto_register: false
# frozen_string_literal: true

module Admin
  class LinkRecordAction < Action
    LINKED = "record_links.toasts.linked"

    include Deps[link_records: "links.operations.link_records"]

    def handle(request, response)
      id = record_id(request)

      result = link_records.call(self.class::KIND, id, Blog::Types::Fields[request.params[:record]])

      case result
        in Failure[:invalid, errors]
          response.status = 422
          render_refused(request, response, id, errors)
        else settle(response, result, self.class::LINKED, record_path(request, id))
      end
    end

    private

    def records_query(request, errors) = { query: request.params[:record_q], errors: }
  end
end
