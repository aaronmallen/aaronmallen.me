# frozen_string_literal: true

module Admin
  module Actions
    module SavedViews
      class Change < Action
        CHANGED = "saved_views_page.toasts.changed"

        include SavedViewReturn
        include Deps[change_saved_view: "saved_views.operations.change_saved_view"]

        def handle(request, response)
          case change_saved_view.call(record_id(request), filters: request.params[:filters])
          in Success(_) then answer(request, response, CHANGED)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, _] then answer(request, response, INVALID)
          else halt 500
          end
        end
      end
    end
  end
end
