# frozen_string_literal: true

module MCP
  module Tools
    class AddDecisionOption < Base
      description "Add an option to an open decision, with a title and a Markdown body"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
