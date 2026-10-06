# frozen_string_literal: true

module API
  module Serializers
    class SavedView < Serializer
      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          name: Schema::STRING,
          screen: { type: "string", enum: Blog::Types::SavedViewScreen.values },
          filters: Endpoints::SavedViews::FILTERS.except(:description),
        },
      ).freeze

      schema_attributes
    end
  end
end
