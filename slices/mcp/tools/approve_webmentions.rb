# frozen_string_literal: true

module MCP
  module Tools
    class ApproveWebmentions < Base
      description "Approve up to 100 webmentions, so each shows on its blog post. One that is missing approves none. " \
                  "#{Untrusted::WEBMENTIONS}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
