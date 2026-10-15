# frozen_string_literal: true

module MCP
  module Tools
    class UpdateShareGroup < Base
      description "Name a share group by ID. The name titles the group's page and its zip, <name>.zip; null or " \
                  "blank goes back to the code. The link stays the same"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
