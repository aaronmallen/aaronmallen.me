# frozen_string_literal: true

module MCP
  module Tools
    class ImportCommits < Base
      SCHEMA = { additionalProperties: false }.freeze

      description "Queue an import of new commits from GitHub, as the import button on the admin's today page " \
                  "does. It runs in the background, so the commits land a little later; read_sync_state says " \
                  "when the last sync finished and whether one is failing"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:)
          case dep(:queue_commit_import, server_context).call
            in Success(_) then answer(status: "queued")
            in Failure(:not_configured) then refuse("no GitHub token is set, so no import can run")
          end
        end
      end
    end
  end
end
