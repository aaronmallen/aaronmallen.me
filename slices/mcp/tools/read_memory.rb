# frozen_string_literal: true

module MCP
  module Tools
    class ReadMemory < Base
      description "Load the memory an agent should know before it works: the global files, then those for a repo " \
                  "and its projects, a project and a task, as one markdown text, with each file and its facts and " \
                  "their IDs. Give repo as owner/name, project_id and task_id as you know them, or none for the " \
                  "global files alone. #{Untrusted::MEMORY}"
      endpoint
    end
  end
end
