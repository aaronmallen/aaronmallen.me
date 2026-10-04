# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module RecordLinking
      include Dry::Monads[:result]

      LINKED = "record_links.toasts.linked"
      UNLINKED = "record_links.toasts.unlinked"

      private

      def back_to_record(request, response, id, key)
        toast(response, key)
        response.redirect_to(record_path(request, id))
      end

      def link(request, response)
        id = record_id(request)

        case link_records.call(self.class::KIND, id, Blog::Types::Fields[request.params[:record]])
        in Success(_) then back_to_record(request, response, id, LINKED)
        in Failure(:not_found) then halt 404
        in Failure[:invalid, errors] then refuse_link(request, response, id, errors)
        else halt 500
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

        case unlink_records.call(self.class::KIND, id, params[:other_kind], params[:other_id])
        in Success(_) then back_to_record(request, response, id, UNLINKED)
        in Failure(:not_found) then halt 404
        else halt 500
        end
      end
    end
  end
end
