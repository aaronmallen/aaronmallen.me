# frozen_string_literal: true

module API
  module Serializers
    class APIToken < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          name: Helpers::Schema::STRING,
          created_at: Helpers::Schema::STAMP,
          last_used_at: Helpers::Schema.nullable(Helpers::Schema::STAMP.merge(description: "null if never used")),
        },
      ).freeze

      schema_attributes
      stamps :created_at, :last_used_at
    end
  end
end
