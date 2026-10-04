# frozen_string_literal: true

module API
  module Endpoints
    class DeleteSavedView < Endpoint
      SCHEMA = Schema.by_id
      REPLY = Schema.object({ id: Schema::INTEGER, deleted: Schema::BOOLEAN }).freeze

      include Deps[delete_saved_view: "saved_views.operations.delete_saved_view"]

      def handle(id:)
        case delete_saved_view.call(id)
        in Success(_) then Success(id:, deleted: true)
        in Failure(:not_found) then not_found(SavedViews.missing(id))
        else failed("could not delete the saved view")
        end
      end
    end
  end
end
