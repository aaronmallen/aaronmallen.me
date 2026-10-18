# frozen_string_literal: true

module MCP
  module Tools
    class RestoreArtifactVersion < Base
      description "Copy an old version's body forward as a new version, so nothing is lost. Name yourself with " \
                  "agent and model slugs. #{Untrusted::ARTIFACT}"
      endpoint scope: Blog::Types::OAuthScope["agents"]
    end
  end
end
