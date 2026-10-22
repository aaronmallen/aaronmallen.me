# frozen_string_literal: true

module MCP
  module Tools
    class UpdateShare < Base
      description "Edit a shared file by ID: its name, the one a download saves as; its short code, which moves " \
                  "its link; or its alt text. A field you leave out keeps what it has"
      endpoint
    end
  end
end
