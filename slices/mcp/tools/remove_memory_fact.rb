# frozen_string_literal: true

module MCP
  module Tools
    class RemoveMemoryFact < Base
      description "Remove a fact so it stops loading. Its text stays in the history, so reverting the removal brings " \
                  "it back. Name yourself with agent and model slugs"
      endpoint scope: Blog::Types::OAuthScope["agents"]
    end
  end
end
