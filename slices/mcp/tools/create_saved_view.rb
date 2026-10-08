# frozen_string_literal: true

module MCP
  module Tools
    class CreateSavedView < Base
      description "Save a view of an admin screen under a name: the screen and the filters it opens with. A " \
                  "filter the screen does not read is dropped"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
