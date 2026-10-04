# frozen_string_literal: true

module Admin
  module Actions
    module SavedViews
      class Destroy < Action
        DELETED = "saved_views_page.toasts.deleted"

        include SavedViewReturn
        include Deps[delete_saved_view: "saved_views.operations.delete_saved_view"]

        def handle(request, response)
          case delete_saved_view.call(record_id(request))
          in Success(_) then answer(request, response, DELETED)
          in Failure(:not_found) then halt 404
          else halt 500
          end
        end
      end
    end
  end
end
