# frozen_string_literal: true

module MCP
  module Tools
    class MarkWebmentionsSpam < Base
      description "Mark up to 100 webmentions spam and stop auto-approving the authors. One that is missing " \
                  "marks none. #{Untrusted::WEBMENTIONS}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
