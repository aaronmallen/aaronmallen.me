# frozen_string_literal: true

module MCP
  module Tools
    class ComposeAnnouncement < Base
      description "Compose the announcement one blog post sends to social networks when it goes out: its own " \
                  "announcement text, or its title and link when it has none. Nothing is sent"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
