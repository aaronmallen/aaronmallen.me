# frozen_string_literal: true

module MCP
  module Tools
    class StartSession < Base
      description "Open a session at the start of a run and list your memory: the global files, then those for the " \
                  "repo and its projects and for each task. files holds one entry per file with its ID, scope, " \
                  "path, description and fact count, and no facts. Read a file's facts with read_memory_file, or " \
                  "find facts by their words with search_memory. Name yourself with agent and model slugs, such " \
                  "as claude-code and claude-opus-5-5. Pass the session_id it returns on each memory read and " \
                  "search, so the session records the files you read, and on each memory and artifact write, and " \
                  "call end_session when you finish; a session no call names for " \
                  "#{Agents::Repos::AgentSessionQueries::IDLE_HOURS} hours closes on its own. #{Untrusted::MEMORY}"
      endpoint
    end
  end
end
