# frozen_string_literal: true

module MCP
  module Tools
    class UntagNote < Base
      description "Take one private tag off a note. #{Untrusted::NOTES}"
      endpoint
    end
  end
end
