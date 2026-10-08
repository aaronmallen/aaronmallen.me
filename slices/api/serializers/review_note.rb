# frozen_string_literal: true

module API
  module Serializers
    class ReviewNote < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          body: { type: "string", description: "the note, in Markdown" },
          created_at: Helpers::Schema::STAMP,
          updated_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at
    end
  end
end
