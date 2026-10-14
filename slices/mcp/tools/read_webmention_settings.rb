# frozen_string_literal: true

module MCP
  module Tools
    class ReadWebmentionSettings < Base
      description "Read the webmention settings: whether the site receives them, sends them when a post goes " \
                  "live, approves known authors on its own, turns them on for new posts, accepts Bridgy, and which " \
                  "hosts are each one person's site"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
