# frozen_string_literal: true

module API
  module Endpoints
    class ListSavedViews < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { screen: SavedViews::SCREEN.merge(description: "list only the views on this screen") },
      }.freeze

      REPLY = Schema.object({ saved_views: Schema.list(Serializers::SavedView.reference) }).freeze

      include Deps[saved_view_queries: "saved_views.repos.saved_view_queries"]

      def handle(screen: nil)
        Success(saved_views: serialized(Serializers::SavedView, saved_view_queries.all(screen:)))
      end
    end
  end
end
