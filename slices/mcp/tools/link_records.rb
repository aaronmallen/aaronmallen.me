# frozen_string_literal: true

module MCP
  module Tools
    class LinkRecords < Base
      description "Link two records of any kind, such as a task and the post it was for. A pair takes one link. #{Untrusted::LINKS}"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
