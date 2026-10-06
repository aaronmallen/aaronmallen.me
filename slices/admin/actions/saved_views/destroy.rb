# frozen_string_literal: true

module Admin
  module Actions
    module SavedViews
      class Destroy < Action
        DELETED = "saved_views_page.toasts.deleted"

        include SavedViewReturn
        include Deps[delete_saved_view: "saved_views.operations.delete_saved_view"]

        def handle(request, response)
          settle(response, delete_saved_view.call(record_id(request)), DELETED, return_path(request))
        end
      end
    end
  end
end
