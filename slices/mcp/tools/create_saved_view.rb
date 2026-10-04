# frozen_string_literal: true

module MCP
  module Tools
    class CreateSavedView < Base
      description "Save a view of an admin screen under a name: the screen and the filters it opens with. A " \
                  "filter the screen does not read is dropped"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
