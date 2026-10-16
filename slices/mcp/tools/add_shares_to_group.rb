# frozen_string_literal: true

module MCP
  module Tools
    class AddSharesToGroup < Base
      description "Move single shares, by ID, into the share group with the given ID and get the group with each " \
                  "file's link under it. Each share's own link stops working. One that is missing or already sits " \
                  "in a group moves none"
      endpoint scope: Blog::Types::OAuthScope["publish"]
    end
  end
end
