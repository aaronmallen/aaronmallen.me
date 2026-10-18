# frozen_string_literal: true

module MCP
  module Tools
    class RejectSuggestionEdits < Base
      description "Reject pending or stale edits from one set of suggested edits, as the admin does. " \
                  "The text of the blog post or social post stays as it is"
      endpoint
    end
  end
end
