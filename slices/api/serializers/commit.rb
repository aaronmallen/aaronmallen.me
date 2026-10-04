# frozen_string_literal: true

module API
  module Serializers
    class Commit < Serializer
      TIME_FORMAT = "%H:%M"

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

      attributes :id, :sha, :repo, :branch, :message, :date, :time, :additions, :deletions

      def date(commit) = day(commit.commit_date)

      def time(commit) = commit.commit_time.strftime(TIME_FORMAT)
    end
  end
end
