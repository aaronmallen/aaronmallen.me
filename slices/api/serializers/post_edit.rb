# frozen_string_literal: true

module API
  module Serializers
    class PostEdit < Serializer
      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          note: { type: "string", description: "what changed in the published post, and why" },
          created_at: Schema::STAMP,
          updated_at: Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at
    end
  end
end
