# frozen_string_literal: true

module MCP
  module Tools
    class SaveTask < Base
      description "Edit one task, as the admin's task editor does. A field you leave out keeps what it has; " \
                  "tags replace the whole set. #{Untrusted::TASK}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
