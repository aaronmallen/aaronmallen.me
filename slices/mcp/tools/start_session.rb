# frozen_string_literal: true

module MCP
  module Tools
    class StartSession < Base
      description "Open a session at the start of a run and load your memory: the global files, then those for the " \
                  "repo and its projects and for each task, as one markdown text. Each file's header comment names " \
                  "its ID as file <id>, and each fact's bullet starts with [fact <id>]; files lists each file's ID, " \
                  "path and scope without its facts. Name yourself with agent and model slugs, such as claude-code " \
                  "and claude-opus-5-5. Pass the session_id it returns on each memory and artifact write, and call " \
                  "end_session when you finish; a session no call names for " \
                  "#{Agents::Repos::AgentSessionQueries::IDLE_HOURS} hours closes on its own. #{Untrusted::MEMORY}"
      endpoint
    end
  end
end
