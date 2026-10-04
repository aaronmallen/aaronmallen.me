# frozen_string_literal: true

module MCP
  module Tools
    class ReadCommit < Base
      description "Read one commit: its sha, repository, branch, whole message, date, time, lines added and " \
                  "deleted and the records linked to it, grouped by kind"
      input_schema(API::Endpoints::ReadCommit::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:read_commit, input, server_context)
      end
    end
  end
end
