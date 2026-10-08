# frozen_string_literal: true

module API
  module Serializers
    class TaskRule < Serializer
      PROJECT = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, name: Helpers::Schema::STRING }).freeze

      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          pattern: Helpers::Schema::STRING,
          provider: Endpoints::TaskRules::PROVIDER.except(:description),
          tags: Helpers::Schema::TAGS,
          projects: Helpers::Schema.list(PROJECT),
        },
      ).freeze

      schema_attributes
      tag_names

      def projects(rule) = rule.projects.map { { id: it.id, name: it.name } }
    end
  end
end
