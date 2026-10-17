# frozen_string_literal: true

module Admin
  module Actions
    module SavedViews
      class Change < SavedViewAction
        CHANGED = "saved_views_page.toasts.changed"

        include Deps[change_saved_view: "saved_views.operations.change_saved_view"]

        def handle(request, response)
          result = change_saved_view.call(record_id(request), filters: request.params[:filters])

          settle(response, result, CHANGED, return_path(request)) do
            invalid(request, response)
          end
        end
      end
    end
  end
end
