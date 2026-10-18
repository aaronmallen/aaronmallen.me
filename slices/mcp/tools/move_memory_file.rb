# frozen_string_literal: true

module MCP
  module Tools
    class MoveMemoryFile < Base
      description "Move a memory file to another scope: global, repo (give repo as owner/name), project (give " \
                  "project_id) or task (give task_id). It keeps its path and facts, and its history gains a scope " \
                  "entry. Name yourself with agent and model slugs, such as claude-code and claude-opus-5-5"
      endpoint scope: Blog::Types::OAuthScope["agents"]
    end
  end
end
