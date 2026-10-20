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
          repo: Helpers::Schema.nullable(Helpers::Schema::REPO.merge(description: "the repository of a repo file")),
          project_id: Helpers::Schema.nullable({ type: "integer", description: "the project of a project file" }),
          task_id: Helpers::Schema.nullable({ type: "integer", description: "the task of a task file" }),
          facts: Helpers::Schema.list(MemoryFact.reference).merge(description: "the facts it holds, oldest first"),
          created_at: Helpers::Schema::STAMP,
          updated_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at

      def description(file) = file.description_by_agent? ? untrusted(file.description) : file.description

      def facts(file) = MemoryFact.new(file.facts).serializable_hash
    end
  end
end
