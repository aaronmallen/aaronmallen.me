# frozen_string_literal: true

module MCP
  module Tools
    class UploadShareGroup < Base
      description "Share several files under one link on the share host, as the admin's upload does with \"share " \
                  "as one link\" ticked, and get the group's ID, code, link and each file's own link. Send each " \
                  "file's bytes in base64 with its name and, if you know it, its media type. The link opens a page " \
                  "with the images in a carousel, the other files in a list and a zip of them all"
      endpoint scope: Blog::Types::OAuthScope["publish"]
    end
  end
end
