# frozen_string_literal: true

module API
  module Serializers
    class TaskRule < Serializer
      PROJECT = Schema.object({ id: Schema::INTEGER, name: Schema::STRING }).freeze

      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          pattern: Schema::STRING,
          provider: Endpoints::TaskRules::PROVIDER.except(:description),
          tags: Schema::TAGS,
          projects: Schema.list(PROJECT),
        },
      ).freeze

      schema_attributes
      tag_names

      def projects(rule) = rule.projects.map { { id: it.id, name: it.name } }
    end
  end
end
