# frozen_string_literal: true

module MCP
  module Tools
    class ListWorkEntries < Base
      description "List the roles on /projects, the work entries, that overlap a range, in the order the page " \
                  "shows them. A role runs by year, from from_year through to_year, and a role with no to_year " \
                  "is one still held. Give from and to as YYYY-MM-DD; a role counts when any year it covers " \
                  "falls inside the range"
      endpoint
    end
  end
end
