# frozen_string_literal: true

module Admin
  module Actions
    module SavedViews
      class Update < SavedViewAction
        RENAMED = "saved_views_page.toasts.renamed"

        include Deps[change_saved_view: "saved_views.operations.change_saved_view"]

        def handle(request, response)
          result = change_saved_view.call(record_id(request), name_params(request))

          settle(response, result, RENAMED, return_path(request)) do
            invalid(request, response)
          end
        end
      end
    end
  end
end
