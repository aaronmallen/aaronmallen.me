# frozen_string_literal: true

module MCP
  module Tools
    class UpdateSavedView < Base
      description "Rename one saved view, change its filters, or both. A field you leave out keeps what it has, " \
                  "and new filters replace the old ones whole. Its screen stays as it is"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
