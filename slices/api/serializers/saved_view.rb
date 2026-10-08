# frozen_string_literal: true

module API
  module Serializers
    class SavedView < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          name: Helpers::Schema::STRING,
          screen: { type: "string", enum: Blog::Types::SavedViewScreen.values },
          filters: Endpoints::SavedViews::FILTERS.except(:description),
        },
      ).freeze

      schema_attributes
    end
  end
end
