# frozen_string_literal: true

module MCP
  module Tools
    class SuggestEdits < Base
      description "Suggest grammar and spelling edits for one draft or scheduled blog post or unsent social " \
                  "post; they wait for the author to accept or reject and change nothing on their own, " \
                  "and a new set replaces the edits still waiting on that post"
      endpoint
    end
  end
end
