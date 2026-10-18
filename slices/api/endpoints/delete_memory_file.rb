# frozen_string_literal: true

module API
  module Endpoints
    class DeleteMemoryFile < MemoryEndpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, deleted: Helpers::Schema::BOOLEAN }).freeze

      include Deps[delete_memory_file: "agents.operations.delete_memory_file"]

      def handle(id:) = settled(delete_memory_file.call(id), id) { { id:, deleted: true } }
    end
  end
end
