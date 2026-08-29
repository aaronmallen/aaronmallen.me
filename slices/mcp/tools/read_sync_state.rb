# frozen_string_literal: true

require "time"

module MCP
  module Tools
    class ReadSyncState < Base
      SCHEMA = { additionalProperties: false }.freeze

      description "Read how the syncs stand: when commits last synced from GitHub, and each sync failing now, " \
                  "with its repository, reason, message, how many times in a row it failed, when it began " \
                  "failing and when it last failed"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:)
          answer(
            commits_last_synced_at: stamp(commits_last_synced_at(server_context).call),
            failures: sync_failures(server_context).call.map { failure(it) },
          )
        end

        private

        def failure(state)
          {
            sync: state.fetch(:sync),
            repo: state.fetch(:repo),
            reason: state.fetch(:reason),
            message: state.fetch(:message),
            count: state.fetch(:count),
            failing_since: stamp(state.fetch(:since)),
            last_failed_at: stamp(state.fetch(:at)),
          }
        end

        def stamp(time) = time&.utc&.iso8601
      end
    end
  end
end
