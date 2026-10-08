# frozen_string_literal: true

module MCP
  module Tools
    class UploadPhoto < Base
      description "Upload a photo, as the admin's Markdown editor does, and get its URL, width and height. " \
                  "Send its bytes in base64. Put the URL in a post, journal entry, task or comment to use it; " \
                  "the site sweeps a photo no record names. It takes a GIF, HEIC, JPEG, PNG or WebP up to 20 MB"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
