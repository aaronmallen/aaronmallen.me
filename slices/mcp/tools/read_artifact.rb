# frozen_string_literal: true

module MCP
  module Tools
    class ReadArtifact < Base
      description "Read an artifact: its title, type, tags, the body of its latest version or of the version you " \
                  "name, and every version, oldest first, with the agent and model that wrote it, or null for the " \
                  "owner. #{Untrusted::ARTIFACT}"
      endpoint scope: Blog::Types::OAuthScope["agents"]
    end
  end
end
