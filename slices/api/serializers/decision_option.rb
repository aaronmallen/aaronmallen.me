# frozen_string_literal: true

module API
  module Serializers
    class DecisionOption < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          title: Helpers::Schema::STRING,
          body: { type: "string", description: "the option, in Markdown" },
          created_at: Helpers::Schema::STAMP,
          updated_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at
    end
  end
end
