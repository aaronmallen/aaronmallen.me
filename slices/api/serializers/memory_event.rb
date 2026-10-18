# frozen_string_literal: true

module API
  module Serializers
    class MemoryEvent < Serializer
      TYPE = Helpers::Schema.nullable({ type: "string", enum: Blog::Types::MemoryFactType.values })

      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          op: { type: "string", enum: Blog::Types::MemoryEventOp.values },
          fact_id: Helpers::Schema.nullable({ type: "integer", description: "the fact it changed" }),
          type: TYPE.merge(description: "the fact's type after the change; null when it left the fact removed"),
          text: Helpers::Schema.nullable({ type: "string", description: "the fact's text after the change" }),
          was_type: TYPE.merge(description: "the fact's type before the change; null when there was none"),
          was_text: Helpers::Schema.nullable({ type: "string", description: "the fact's text before the change" }),
          reverted_event_id: Helpers::Schema.nullable({ type: "integer", description: "the entry a revert undid" }),
          agent: Helpers::Schema.nullable({ type: "string",
                                            description: "the agent that made it; null for the owner" }),
          model: Helpers::Schema.nullable({ type: "string",
                                            description: "the model that made it; null for the owner" }),
          created_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at

      def fact_id(event) = event.memory_fact_id

      def text(event) = event.text&.then { untrusted(it) }

      def was_text(event) = event.was_text&.then { untrusted(it) }
    end
  end
end
