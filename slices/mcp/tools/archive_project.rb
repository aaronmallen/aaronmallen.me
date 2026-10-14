# frozen_string_literal: true

module MCP
  module Tools
    class ArchiveProject < Base
      description "Archive one project as of today, which takes it off /projects. " \
                  "A project whose start month has not come yet stays as it is"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
