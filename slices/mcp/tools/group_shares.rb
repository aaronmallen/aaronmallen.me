# frozen_string_literal: true

module MCP
  module Tools
    class GroupShares < Base
      description "Group two or more single shares, by ID, under one new link, as the admin's files list does, and " \
                  "get the group with each file's link under it. Each share's own link stops working. One that is " \
                  "missing or already sits in a group groups none"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
