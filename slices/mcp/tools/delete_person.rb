# frozen_string_literal: true

module MCP
  module Tools
    class DeletePerson < Base
      description "Remove one contact for good, from Google too when it syncs with a Google account. Posts that " \
                  "mention them keep the token"
      endpoint
    end
  end
end
