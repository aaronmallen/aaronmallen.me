# frozen_string_literal: true

module MCP
  module Tools
    class UntagSession < Base
      description "Take one tag off a session. #{Untrusted::SESSIONS}"
      endpoint
    end
  end
end
