# frozen_string_literal: true

module API
  module Serializers
    class DeadJob < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          name: { **Helpers::Schema::STRING, description: "the job's class" },
          died_at: { **Helpers::Schema::STAMP, description: "when the job ran out of retries" },
          error: { **Helpers::Schema::STRING, description: "the error class and message it last failed with" },
        },
      ).freeze

      schema_attributes
      stamps :died_at
    end
  end
end
