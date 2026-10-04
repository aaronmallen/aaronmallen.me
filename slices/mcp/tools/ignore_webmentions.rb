# frozen_string_literal: true

module MCP
  module Tools
    class IgnoreWebmentions < Base
      description "Hide up to 100 webmentions as ignored, leaving their authors alone. One that is missing hides none"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
