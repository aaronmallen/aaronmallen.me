# frozen_string_literal: true

module MCP
  module Tools
    class AddDecisionOption < Base
      description "Add an option to an open decision, with a title and a Markdown body"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
