# frozen_string_literal: true

module MCP
  module Tools
    class LinkRecords < Base
      description "Link two records of any kind, such as a task and the post it was for. A pair takes one link. #{Untrusted::LINKS}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
