# frozen_string_literal: true

module MCP
  module Tools
    class ListProjects < Base
      description "List every project, public and private: the active ones first, then the archived ones, " \
                  "newest archived first. Each carries its status, its visibility, the day it started and the " \
                  "day it was archived as YYYY-MM-DD, its tags, repository, links, stars and latest release"
      endpoint
    end
  end
end
