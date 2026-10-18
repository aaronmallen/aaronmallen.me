# frozen_string_literal: true

module MCP
  module Tools
    class EditMemoryFact < Base
      description "Change a fact's type or text. The history keeps the old one, so the change can be reverted. Name " \
                  "yourself with agent and model slugs"
      endpoint scope: Blog::Types::OAuthScope["agents"]
    end
  end
end
