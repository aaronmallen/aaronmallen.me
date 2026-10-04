# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class UnlinkRecord < Action
        KIND = Blog::Types::RecordKind["task"]
        UNLINKED = "tasks_page.toasts.record_unlinked"

        include Redirect
        include Deps[unlink_records: "links.operations.unlink_records"]

        def handle(request, response)
          params = request.params

          case unlink_records.call(KIND, record_id(request), params[:other_kind], params[:other_id])
          in Success(_)
            toast(response, UNLINKED)
            response.redirect_to(tasks_path(request))
          in Failure(:not_found) then halt 404
          else halt 500
          end
        end
      end
    end
  end
end
