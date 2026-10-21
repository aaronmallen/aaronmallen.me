# frozen_string_literal: true

module MCP
  module Tools
    class SearchMemory < Base
      description "Find the live facts whose text holds the query, oldest first, each with the ID and path of the " \
                  "file that holds it; read_memory_file reads that file whole. Give repo as owner/name, " \
                  "project_id or task_id to search the files read_memory lists for them, and scope to keep one " \
                  "scope; leave them all out to search every file. count gives the facts on this page. Give " \
                  "session_id to record the search, its facts and the files they came from against that session. " \
                  "#{API::Helpers::Paging::USAGE}. #{Untrusted::MEMORY}"
      endpoint
    end
  end
end
