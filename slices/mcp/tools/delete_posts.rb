# frozen_string_literal: true

module MCP
  module Tools
    class DeletePosts < Base
      description "Delete up to 100 draft blog posts at once. One that is missing or not a draft deletes none. No undo"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
