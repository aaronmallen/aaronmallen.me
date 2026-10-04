# frozen_string_literal: true

module MCP
  module Tools
    class AddDecisionComment < Base
      description "Add a Markdown comment to a decision, open or closed, to keep your thinking as it goes"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
