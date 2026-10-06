# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module RecordLinking
      include Dry::Monads[:result]

      LINKED = "record_links.toasts.linked"
      UNLINKED = "record_links.toasts.unlinked"

      private

      def link(request, response)
        id = record_id(request)

        result = link_records.call(self.class::KIND, id, Blog::Types::Fields[request.params[:record]])

        case result
        in Failure[:invalid, errors] then refuse_link(request, response, id, errors)
        else settle(response, result, self.class::LINKED, record_path(request, id))
        end
      end

      def linked_records(request, id, errors)
        list_record_links.call(self.class::KIND, id, **records_query(request, errors))
      end

      def records_query(request, errors) = { query: request.params[:record_q], errors: }

      def refuse_link(request, response, id, errors)
        response.status = 422
        render_refused(request, response, id, errors)
      end

      def unlink(request, response)
        id = record_id(request)
        params = request.params

        result = unlink_records.call(self.class::KIND, id, params[:other_kind], params[:other_id])
        settle(response, result, self.class::UNLINKED, record_path(request, id))
      end
    end
  end
end
