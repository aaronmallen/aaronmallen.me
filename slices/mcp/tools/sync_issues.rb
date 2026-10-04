# frozen_string_literal: true

module MCP
  module Tools
    class SyncIssues < Base
      description "Queue a sync of the GitHub and Linear issues assigned to me, as the sync button on the " \
                  "admin's External tab does, and say which sources it queued. It runs in the background, so " \
                  "new issues land a little later; read_sync_state says when the last sync finished"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
