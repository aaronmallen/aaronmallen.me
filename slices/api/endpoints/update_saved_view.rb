# frozen_string_literal: true

module API
  module Endpoints
    class UpdateSavedView < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          filters: SavedViews::FILTERS.merge(description: "the new filters, which replace the old ones whole"),
          id: SavedViews::ID,
          name: SavedViews::NAME.merge(description: "the new name, up to 100 characters"),
        },
        required: ["id"],
      }.freeze

      REPLY = Serializers::SavedView.reference

      include Deps[
        change_saved_view: "saved_views.operations.change_saved_view",
        rename_saved_view: "saved_views.operations.rename_saved_view",
        saved_view_by_id: "saved_views.queries.by_id",
      ]

      def handle(id:, name: nil, filters: nil)
        view = saved_view_by_id.call(id)
        return not_found(SavedViews.missing(id)) if view.nil?

        result = Success(view)
        result = result.bind { rename_saved_view.call(id, name:) } unless name.nil?
        result = result.bind { change_saved_view.call(id, filters:) } unless filters.nil?
        saved(id, result)
      end

      private

      def saved(id, result)
        case result
        in Success(view) then Success(serialized(Serializers::SavedView, view))
        in Failure[:invalid, errors] then invalid(SavedViews.complaints(errors))
        in Failure(:not_found) then not_found(SavedViews.missing(id))
        else failed(SavedViews::UNSAVED)
        end
      end
    end
  end
end
