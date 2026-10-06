# frozen_string_literal: true

module MCP
  module Tools
    class DeletePerson < Base
      description "Remove one person from the mention directory for good. Posts that mention them keep the token"
      endpoint scope: OAuth::Scope::DELETE
    end
  end
end
