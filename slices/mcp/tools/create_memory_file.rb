# frozen_string_literal: true

module MCP
  module Tools
    class CreateMemoryFile < Base
      description "Start a memory file. A path such as hanami gains .md, and is unique within its scope: global, " \
                  "project (give project_id) or task (give task_id). Describe it in one line: what it covers and " \
                  "when to read it. Name yourself with agent and model slugs, such as claude-code and claude-opus-5-5"
      endpoint
    end
  end
end
