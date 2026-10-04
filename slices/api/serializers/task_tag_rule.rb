# frozen_string_literal: true

module API
  module Serializers
    class TaskTagRule < Serializer
      SCHEMA = Schema.object({ id: Schema::INTEGER, pattern: Schema::STRING, tags: Schema::TAGS }).freeze

      attributes :id, :pattern, :tags

      def tags(rule) = rule.tags.map(&:name)
    end
  end
end
