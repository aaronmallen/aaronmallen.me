# frozen_string_literal: true

module API
  module Serializers
    class NoteFolder < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          name: Helpers::Schema::STRING,
          description: Helpers::Schema::STRING,
          parent_id: Helpers::Schema.nullable(
            { type: "integer", description: "the folder it sits in; null at the top level" },
          ),
          created_at: Helpers::Schema::STAMP,
          updated_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at
    end
  end
end
