# frozen_string_literal: true

module API
  module Endpoints
    class CreateSavedView < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { filters: SavedViews::FILTERS, name: SavedViews::NAME, screen: SavedViews::SCREEN },
        required: %w[name screen],
      }.freeze

      REPLY = Serializers::SavedView.reference

      include Deps[create_saved_view: "saved_views.operations.create_saved_view"]

      def handle(name:, screen:, filters: {})
        case create_saved_view.call(name:, screen:, filters:)
          in Success(view) then Success(serialized(Serializers::SavedView, view))
          in Failure[:invalid, errors]
            invalid(Helpers::Wording.complaints(errors, SavedViews::COMPLAINTS, named: true))
          else failed(SavedViews::UNSAVED)
        end
      end
    end
  end
end
