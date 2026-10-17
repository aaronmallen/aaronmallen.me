# frozen_string_literal: true

module MCP
  module Tools
    class ReadWebmention < Base
      description "Read one webmention by ID, such as a webmention hit from search: the blog post it names, with " \
                  "that post's title and slug, its type, its status, its source and author, its excerpt, and the " \
                  "reason given for spam. #{Untrusted::WEBMENTIONS}"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
