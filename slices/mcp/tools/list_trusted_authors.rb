# frozen_string_literal: true

module MCP
  module Tools
    class ListTrustedAuthors < Base
      description "List the trusted webmention authors, newest first, each with its author URL and when it joined. " \
                  "An author joins when you approve one of their replies or mentions by hand, and leaves when one " \
                  "of their webmentions is marked spam or remove_trusted_author removes them. While " \
                  "auto_approve_known_authors is on, their replies and mentions approve on receipt. No tool adds " \
                  "an author. The author URL, taken from the sender's page, comes marked untrusted. " \
                  "#{Untrusted::WARNING}"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
