# frozen_string_literal: true

module MCP
  module Tools
    class UpdateWebmentionSettings < Base
      description "Change the webmention settings. A setting you leave out keeps what it has. " \
                  "A call that changes nothing saves nothing and says so"
      endpoint scope: Blog::Types::OAuthScope["publish"]
    end
  end
end
