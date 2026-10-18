# frozen_string_literal: true

module API
  module Serializers
    class ArtifactVersion < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          number: Helpers::Schema::INTEGER,
          note: Helpers::Schema.nullable(
            { type: "string", description: "what changed; marked untrusted when an agent wrote it" },
          ),
          agent: Helpers::Schema.nullable({ type: "string",
                                            description: "the agent that wrote it; null for the owner" }),
          model: Helpers::Schema.nullable({ type: "string",
                                            description: "the model that wrote it; null for the owner" }),
          created_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at

      def note(version) = version.agent? ? version.note&.then { untrusted(it) } : version.note
    end
  end
end
