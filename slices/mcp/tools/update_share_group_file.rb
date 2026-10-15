# frozen_string_literal: true

module MCP
  module Tools
    class UpdateShareGroupFile < Base
      description "Rename a file in a share group, by the group's ID and the file's. The new name is the one a " \
                  "download saves as and the file's name in the zip, and its link stays the same"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
