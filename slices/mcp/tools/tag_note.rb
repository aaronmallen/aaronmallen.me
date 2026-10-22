# frozen_string_literal: true

module MCP
  module Tools
    class TagNote < Base
      description "Add one private tag to a note. The tags it already carries stay. #{Untrusted::NOTES}"
      endpoint
    end
  end
end
