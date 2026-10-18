# frozen_string_literal: true

module MCP
  module Tools
    class TagPosts < Base
      description "Add one public tag to up to #{Blog::Contract::MAX_IDS} blog posts at once. One that is missing " \
                  "tags none"
      endpoint
    end
  end
end
