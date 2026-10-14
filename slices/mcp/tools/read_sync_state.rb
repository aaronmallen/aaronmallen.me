# frozen_string_literal: true

module MCP
  module Tools
    class ReadSyncState < Base
      description "Read how the syncs stand: when commits last synced from GitHub, and each sync failing now, " \
                  "with its repository, reason, message, how many times in a row it failed, when it began " \
                  "failing and when it last failed"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
