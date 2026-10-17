# frozen_string_literal: true

module API
  module Serializers
    class Commit < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          sha: Helpers::Schema::STRING,
          repo: Helpers::Schema::REPO,
          branch: Helpers::Schema::STRING,
          message: { type: "string", description: "the whole commit message, subject and body" },
          date: Helpers::Schema::DAY,
          time: Helpers::Schema::CLOCK,
          additions: { type: "integer", description: "lines added" },
          deletions: { type: "integer", description: "lines deleted" },
        },
      ).freeze

      schema_attributes
      untrusted :message

      def date(commit) = day(commit.commit_date)

      def time(commit) = clock(commit.commit_time)
    end
  end
end
