# frozen_string_literal: true

module API
  module Endpoints
    class RevertMemoryEvent < MemoryEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Memory::ID,
          event_id: Memory::ID.merge(description: "the history entry to undo: an add, an edit or a remove"),
          **Memory::AUTHOR,
        },
        required: %w[id event_id agent model],
      }.freeze

      REPLY = Serializers::MemoryEvent.reference

      include Deps[revert_memory_event: "agents.operations.revert_memory_event"]

      def handle(id:, event_id:, **author)
        result = revert_memory_event.call(id, event_id, author)
        settled(result, id, missing: Memory.missing_event(id, event_id)) { serialized(Serializers::MemoryEvent, it) }
      end
    end
  end
end
