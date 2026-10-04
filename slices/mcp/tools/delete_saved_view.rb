# frozen_string_literal: true

module MCP
  module Tools
    class DeleteSavedView < Base
      description "Delete one saved view for good. It cannot come back"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
