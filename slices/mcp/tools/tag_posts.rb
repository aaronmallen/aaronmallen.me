# frozen_string_literal: true

module MCP
  module Tools
    class TagPosts < Base
      description "Add one public tag to up to 100 blog posts at once. One that is missing tags none"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
