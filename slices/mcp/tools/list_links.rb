# frozen_string_literal: true

module MCP
  module Tools
    class ListLinks < Base
      description "List the records linked to one record, grouped by kind. #{Untrusted::LINKS}"
      endpoint scope: OAuth::Scope::READ
    end
  end
end
