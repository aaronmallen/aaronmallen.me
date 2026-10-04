# frozen_string_literal: true

module MCP
  module Tools
    class ReadWebmention < Base
      description "Read one webmention by ID, such as a webmention hit from search: the blog post it names, with " \
                  "that post's title and slug, its type, its status, its source and author, its excerpt, and the " \
                  "reason given for spam. The source, author name, author URL and excerpt, taken from the " \
                  "sender's page, come marked untrusted. #{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::READ

      class << self
        private

        def answered(webmention) = Webmentions.marked(webmention)
      end
    end
  end
end
