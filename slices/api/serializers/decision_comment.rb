# frozen_string_literal: true

module API
  module Serializers
    class DecisionComment < Serializer
      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          body: { type: "string", description: "the comment, in Markdown" },
          created_at: Schema::STAMP,
          updated_at: Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at
    end
  end
end
