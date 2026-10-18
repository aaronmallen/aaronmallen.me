# frozen_string_literal: true

module API
  module Endpoints
    class ReadTag < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          name: { type: "string", description: "the tag's name, in either scope" },
          kind: {
            type: "string",
            enum: Blog::Types::TagKind.values,
            description: "one kind to page through; every kind when you leave it out",
          },
          page: Helpers::Paging::PAGE,
        },
        required: %w[name],
      }.freeze

      REPLY = Serializers::TagOverview::SCHEMA

      include Deps[tag_queries: "tags.repos.tag_queries"]

      def handle(name:, kind: nil, page: 1)
        overview = tag_queries.overview(name.strip.downcase, page_of(page), kind:)
        return missing("tag", name, by: "name") if overview.nil?

        Success(serialized(Serializers::TagOverview, overview))
      end
    end
  end
end
