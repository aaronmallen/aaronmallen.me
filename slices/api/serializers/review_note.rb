# frozen_string_literal: true

module API
  module Serializers
    class ReviewNote < Serializer
      SCHEMA = Schema.object(
        {
          body: { type: "string", description: "the note, in Markdown" },
          created_at: Schema::STAMP,
          updated_at: Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at
    end
  end
end
