# frozen_string_literal: true

module MCP
  module Tools
    class RemoveTrustedAuthor < Base
      description "Remove one author from the trusted webmention authors, by the author URL list_trusted_authors " \
                  "gives. Their approved webmentions stay approved. Their next reply or mention waits for review, " \
                  "and approving one by hand puts them back"
      endpoint
    end
  end
end
