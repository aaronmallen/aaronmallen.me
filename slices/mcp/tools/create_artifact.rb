# frozen_string_literal: true

module MCP
  module Tools
    class CreateArtifact < Base
      description "Write a plan, spec, research, handoff, notes, review, postmortem or other document as a numbered " \
                  "artifact that outlives the session. The body is Markdown of at most " \
                  "#{Agents::Contracts::ArtifactContract::BODY_LIMIT} characters and becomes version 1. Name " \
                  "yourself with agent and model slugs, such as claude-code and claude-opus-5-5"
      endpoint
    end
  end
end
