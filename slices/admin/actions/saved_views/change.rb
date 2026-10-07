# frozen_string_literal: true

module Admin
  module Actions
    module SavedViews
      class Change < Action
        CHANGED = "saved_views_page.toasts.changed"

        include SavedViewReturn
        include Deps[change_saved_view: "saved_views.operations.change_saved_view"]

        def handle(request, response)
          result = change_saved_view.call(record_id(request), filters: request.params[:filters])

          case result
            in Failure[:invalid, _] then answer(request, response, INVALID)
            else settle(response, result, CHANGED, return_path(request))
          end
        end
      end
    end
  end
end
