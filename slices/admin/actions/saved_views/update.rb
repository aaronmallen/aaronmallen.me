# frozen_string_literal: true

module Admin
  module Actions
    module SavedViews
      class Update < Action
        RENAMED = "saved_views_page.toasts.renamed"

        include SavedViewReturn
        include Deps[rename_saved_view: "saved_views.operations.rename_saved_view"]

        def handle(request, response)
          result = rename_saved_view.call(record_id(request), name_params(request))

          case result
          in Failure[:invalid, _] then answer(request, response, INVALID)
          else settle(response, result, RENAMED, return_path(request))
          end
        end
      end
    end
  end
end
