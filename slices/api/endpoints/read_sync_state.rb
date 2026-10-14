# frozen_string_literal: true

module API
  module Endpoints
    class ReadSyncState < Endpoint
      SCHEMA = { additionalProperties: false, properties: {} }.freeze

      FAILURE = Helpers::Schema.object(
        {
          sync: { type: "string", enum: Blog::Types::SyncName.values },
          repo: Helpers::Schema.nullable({ type: "string", description: "the repository, as owner/name" }),
          reason: Helpers::Schema::STRING,
          message: Helpers::Schema.nullable(Helpers::Schema::STRING),
          count: { type: "integer", description: "how many times in a row it failed" },
          failing_since: Helpers::Schema::STAMP,
          last_failed_at: Helpers::Schema::STAMP,
        },
      ).freeze

      REPLY = Helpers::Schema.object(
        {
          commits_last_synced_at: Helpers::Schema.nullable(Helpers::Schema::STAMP),
          failures: Helpers::Schema.list(FAILURE),
        },
      ).freeze

      include Deps[
        commit_queries: "record.repos.commit_queries",
        sync_state_queries: "record.repos.sync_state_queries",
      ]

      def handle
        Success(
          commits_last_synced_at: stamp(commit_queries.last_synced_at),
          failures: sync_state_queries.failures.map { failure(it) },
        )
      end

      private

      def failure(state)
        {
          **state.slice(:sync, :repo, :reason, :message, :count),
          failing_since: stamp(state.fetch(:since)),
          last_failed_at: stamp(state.fetch(:at)),
        }
      end

      def stamp(time) = time&.utc&.iso8601
    end
  end
end
