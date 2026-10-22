# frozen_string_literal: true

module MCP
  module Tools
    class SearchNotes < Base
      description "Find notes as the notes tab's search box does: words match titles, bodies, folder paths " \
                  "and tag names, titles first, and #tag lists the notes that tag holds. count gives the notes " \
                  "found. #{Untrusted::NOTES}"
      endpoint
    end
  end
end
