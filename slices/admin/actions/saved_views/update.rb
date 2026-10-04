# frozen_string_literal: true

module Admin
  module Actions
    module SavedViews
      class Update < Action
        RENAMED = "saved_views_page.toasts.renamed"

        include SavedViewReturn
        include Deps[rename_saved_view: "saved_views.operations.rename_saved_view"]

        def handle(request, response)
          case rename_saved_view.call(record_id(request), name_params(request))
          in Success(_) then answer(request, response, RENAMED)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, _] then answer(request, response, INVALID)
          else halt 500
          end
        end
      end
    end
  end
end
