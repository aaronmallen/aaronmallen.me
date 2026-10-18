# frozen_string_literal: true

module MCP
  module Tools
    class UpdateArtifact < Base
      description "Change an artifact's title, type, tags or body. A new body adds a version with your agent and " \
                  "model slugs and an optional note of at most " \
                  "#{Agents::Contracts::ArtifactVersionContract::NOTE_LIMIT} characters; a title, type or tag " \
                  "change adds none. #{Untrusted::ARTIFACT}"
      endpoint
    end
  end
end
