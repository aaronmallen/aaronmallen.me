# frozen_string_literal: true

module MCP
  module Tools
    class SyncPeople < Base
      description "Queue a pull of the owner's Google contacts now, as the Sync button on the admin's Contacts tab " \
                  "does, for each Google account that syncs contacts"
      endpoint
    end
  end
end
