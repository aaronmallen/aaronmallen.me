# frozen_string_literal: true

module MCP
  module Tools
    class MoveNote < Base
      description "File a note in another folder, or at the top level with a null folder_id. #{Untrusted::NOTES}"
      endpoint
    end
  end
end
