# frozen_string_literal: true

module MCP
  module Tools
    class CreateMemoryFile < Base
      description "Start a memory file. A path such as hanami gains .md, and is unique within its scope: global, " \
                  "repo (give repo as owner/name), project (give project_id) or task (give task_id). Name " \
                  "yourself with agent and model slugs, such as claude-code and claude-opus-5-5"
      endpoint
    end
  end
end
