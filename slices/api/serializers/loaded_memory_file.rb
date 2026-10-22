# frozen_string_literal: true

module API
  module Serializers
    class LoadedMemoryFile < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          **MemoryFile::SCHEMA.fetch(:properties).slice(:id, :path, :description, :scope, :project_id, :task_id),
          fact_count: { type: "integer", description: "the live facts it holds" },
        },
      ).freeze

      schema_attributes

      def description(file) = file.description_by_agent? ? untrusted(file.description) : file.description

      def fact_count(file) = file.facts.size
    end
  end
end
