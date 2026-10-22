# frozen_string_literal: true

module MCP
  module Tools
    class CheckPostLinks < Base
      description "Queue a fresh check of every link in one published blog post by ID, or of the one link given " \
                  "in url, as the post's links drawer in the admin does. It runs in the background; " \
                  "list_attention shows a link that keeps failing"
      endpoint
    end
  end
end
