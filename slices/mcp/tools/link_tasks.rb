# frozen_string_literal: true

module MCP
  module Tools
    class LinkTasks < Base
      description "Link one task to another. A pair takes one link, whichever way it runs"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
