# frozen_string_literal: true

module MCP
  module Tools
    class UnlinkRecords < Base
      description "Remove the link between two records, whichever side it was made from. #{Untrusted::LINKS}"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
