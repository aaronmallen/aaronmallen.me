# frozen_string_literal: true

module API
  module Serializers
    class Commit < Serializer
      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          sha: Schema::STRING,
          repo: { type: "string", description: "the repository, as owner/name" },
          branch: Schema::STRING,
          message: { type: "string", description: "the whole commit message, subject and body" },
          date: Schema::DAY,
          time: { type: "string", description: "the time of day, as HH:MM" },
          additions: { type: "integer", description: "lines added" },
          deletions: { type: "integer", description: "lines deleted" },
        },
      ).freeze

      schema_attributes

      def date(commit) = day(commit.commit_date)

      def time(commit) = clock(commit.commit_time)
    end
  end
end
