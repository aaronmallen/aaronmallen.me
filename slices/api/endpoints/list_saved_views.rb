# frozen_string_literal: true

module API
  module Endpoints
    class ListSavedViews < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { screen: SavedViews::SCREEN.merge(description: "list only the views on this screen") },
      }.freeze

      REPLY = Schema.object({ saved_views: Schema.list(Serializers::SavedView.reference) }).freeze

      include Deps[all_saved_views: "saved_views.queries.all"]

      def handle(screen: nil)
        Success(saved_views: serialized(Serializers::SavedView, all_saved_views.call(screen:)))
      end
    end
  end
end
