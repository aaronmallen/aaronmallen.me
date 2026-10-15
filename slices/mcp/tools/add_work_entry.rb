# frozen_string_literal: true

module MCP
  module Tools
    class AddWorkEntry < Base
      description "Add a role to the end of the work list on /projects"
      endpoint scope: Blog::Types::OAuthScope["publish"]
    end
  end
end
