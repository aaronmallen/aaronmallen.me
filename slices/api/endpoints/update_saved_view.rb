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
        saved_view_queries: "saved_views.repos.saved_view_queries",
      ]

      def handle(id:, name: nil, filters: nil)
        view = saved_view_queries.by_id(id)
        return not_found(Helpers::Wording.missing("saved view", id)) if view.nil?

        saved(id, change_saved_view.call(id, name: name || view.name, filters: filters || view.filters))
      end

      private

      def saved(id, result)
        case result
          in Success(view) then Success(serialized(Serializers::SavedView, view))
          in Failure[:invalid, errors]
            invalid(Helpers::Wording.complaints(errors, SavedViews::COMPLAINTS, named: true))
          in Failure(:not_found) then not_found(Helpers::Wording.missing("saved view", id))
          else failed(SavedViews::UNSAVED)
        end
      end
    end
  end
end
