# frozen_string_literal: true

module API
  module Serializers
    class Photo < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          url: { type: "string", description: "where the photo lives; a record whose text names it claims it" },
          width: Helpers::Schema::INTEGER,
          height: Helpers::Schema::INTEGER,
        },
      ).freeze

      schema_attributes
    end
  end
end
