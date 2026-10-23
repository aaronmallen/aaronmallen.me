# frozen_string_literal: true

module API
  module Serializers
    class MemoryFile < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          path: Helpers::Schema::STRING,
          description: Helpers::Schema.nullable(
            { type: "string",
              description: "what it covers and when to read it; marked untrusted when an agent set it" },
          ),
          scope: { type: "string", enum: Blog::Types::MemoryScope.values },
          project_id: Helpers::Schema.nullable({ type: "integer", description: "the project of a project file" }),
          task_id: Helpers::Schema.nullable({ type: "integer", description: "the task of a task file" }),
          facts: Helpers::Schema.list(MemoryFact.reference).merge(description: "the facts it holds, oldest first"),
          tags: Helpers::Schema::TAGS.merge(description: "its tags; a project file's are its project's own tags"),
          created_at: Helpers::Schema::STAMP,
          updated_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at

      def description(file) = file.description_by_agent? ? untrusted(file.description) : file.description

      def facts(file) = MemoryFact.new(file.facts).serializable_hash

      def tags(file) = file.tags.map(&:name)
    end
  end
end
