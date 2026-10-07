# frozen_string_literal: true

module API
  module Endpoints
    class ReadTag < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { name: { type: "string", description: "the tag's name, in either scope" } },
        required: %w[name],
      }.freeze

      REPLY = Serializers::TagSummary::SCHEMA

      include Deps[tag_queries: "tags.repos.tag_queries"]

      def handle(name:)
        summary = tag_queries.summary(name.strip.downcase)
        return not_found(Wording.missing("tag", name, by: "name")) if summary.nil?

        Success(serialized(Serializers::TagSummary, summary))
      end
    end
  end
end
