# frozen_string_literal: true

module MCP
  module Tools
    class TagSession < Base
      description "Add one tag to a session. A session in a project takes its project's own tag of the name, made " \
                  "there when missing; a session with no project takes a private tag. The tags it already " \
                  "carries stay. #{Untrusted::SESSIONS}"
      endpoint
    end
  end
end
