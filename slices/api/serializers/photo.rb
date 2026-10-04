# frozen_string_literal: true

module API
  module Serializers
    class Photo < Serializer
      SCHEMA = Schema.object(
        {
          url: { type: "string", description: "where the photo lives; a record whose text names it claims it" },
          width: Schema::INTEGER,
          height: Schema::INTEGER,
        },
      ).freeze

      attributes :url, :width, :height
    end
  end
end
