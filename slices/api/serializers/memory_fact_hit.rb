# frozen_string_literal: true

module API
  module Serializers
    class MemoryFactHit < MemoryFact
      SCHEMA = Helpers::Schema.widen(
        MemoryFact::SCHEMA,
        memory_file_id: { type: "integer", description: "the file that holds it, for read_memory_file" },
        path: { type: "string", description: "the path of the file that holds it" },
      ).freeze

      attributes :memory_file_id, :path

      def path(fact) = fact.memory_file.path
    end
  end
end
