# frozen_string_literal: true

module MCP
  module Tools
    class ModerateWebmention < Base
      description "Approve one webmention, so it shows on its blog post, or hide it as ignored or spam"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
