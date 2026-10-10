# frozen_string_literal: true

module MCP
  module Tools
    class DeletePosts < Base
      description "Delete up to #{Blog::Contract::MAX_IDS} draft blog posts at once. One that is missing or not a " \
                  "draft deletes none. No undo"
      endpoint scope: Blog::Types::OAuthScope["delete"]
    end
  end
end
