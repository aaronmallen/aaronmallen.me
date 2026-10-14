# frozen_string_literal: true

module MCP
  module Tools
    class ImportCommits < Base
      description "Queue an import of new commits from GitHub, as the import button on the admin's today page " \
                  "does. It runs in the background, so the commits land a little later; read_sync_state says " \
                  "when the last sync finished and whether one is failing"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
