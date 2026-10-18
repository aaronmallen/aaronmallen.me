# frozen_string_literal: true

module MCP
  module Tools
    class EndSession < Base
      description "Close a session start_session opened, once your run is done. A session closes once; a second " \
                  "call is refused. #{Untrusted::SESSIONS}"
      endpoint scope: Blog::Types::OAuthScope["agents"]
    end
  end
end
