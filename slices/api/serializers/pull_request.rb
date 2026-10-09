# frozen_string_literal: true

module API
  module Serializers
    class PullRequest < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          repo: { type: "string", description: "the repository, as owner/name" },
          number: Helpers::Schema::INTEGER,
          title: Helpers::Schema::STRING,
          description: Helpers::Schema::STRING,
          url: Helpers::Schema::STRING,
          state: {
            type: "string",
            enum: Blog::Types::PullRequestState.values,
            description: "draft until it is ready for review, open once it is, then merged or closed",
          },
          ready_at: Helpers::Schema.nullable(Helpers::Schema::STAMP.merge(description: "when it was ready for review")),
          merged_at: Helpers::Schema.nullable(Helpers::Schema::STAMP),
          closed_at: Helpers::Schema.nullable(Helpers::Schema::STAMP.merge(description: "when it closed unmerged")),
        },
      ).freeze

      schema_attributes
      stamps :ready_at, :merged_at, :closed_at

      def description(pull_request) = pull_request.body
    end
  end
end
