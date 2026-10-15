# frozen_string_literal: true

module MCP
  module Tools
    class UpdateShare < Base
      description "Rename a shared file by ID. The new name is the one a download saves as, and the link stays " \
                  "the same"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
