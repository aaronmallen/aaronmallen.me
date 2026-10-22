# frozen_string_literal: true

module MCP
  module Tools
    class SearchMemory < Base
      description "Find the live facts whose text holds the query, oldest first, each with the ID and path of the " \
                  "file that holds it; read_memory_file reads that file whole. Give a project key in project, repo " \
                  "as owner/name to look up its project, project_id or task_id to search the files read_memory lists " \
                  "for them, and scope to keep one scope; leave them all out to search every file. A repo no project " \
                  "holds searches no project files and makes no project, since only start_session makes one, and " \
                  "an unknown key is refused. count gives the facts on this page. Give session_id to record the " \
                  "search, its facts and the files they came from against that session; an ended session still " \
                  "allows the search but records nothing. " \
                  "#{API::Helpers::Paging::USAGE}. #{Untrusted::MEMORY}"
      endpoint
    end
  end
end
