# frozen_string_literal: true

module API
  module Serializers
    class DecisionOption < Serializer
      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          title: Schema::STRING,
          body: { type: "string", description: "the option, in Markdown" },
          created_at: Schema::STAMP,
          updated_at: Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at
    end
  end
end
