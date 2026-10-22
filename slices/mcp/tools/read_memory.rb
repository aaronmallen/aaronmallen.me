# frozen_string_literal: true

module MCP
  module Tools
    class ReadMemory < Base
      description "List the memory files an agent should know of before it works: the global files, then those " \
                  "for a project and a task. files holds one entry per file with its ID, scope, path, " \
                  "description and fact count, and no facts. Read a file's facts with read_memory_file, or find " \
                  "facts by their words with search_memory. Name the project by its key in project, or give repo " \
                  "as owner/name to look up the project that holds it; a repo no project holds lists no project " \
                  "files and makes no project, since only start_session makes one. An unknown key is refused. " \
                  "Give project_id and task_id as you know them, or none for the global files alone. " \
                  "#{Untrusted::MEMORY}"
      endpoint
    end
  end
end
