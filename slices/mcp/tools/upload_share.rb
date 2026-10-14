# frozen_string_literal: true

module MCP
  module Tools
    class UploadShare < Base
      description "Share one file under its own link on the share host, as the admin's upload does, and get the " \
                  "share's ID, code, link and size. Send its bytes in base64 with the name the link hands it out " \
                  "under, and its media type if you know it. The link returns the raw file"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
