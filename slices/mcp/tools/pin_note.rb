# frozen_string_literal: true

module MCP
  module Tools
    class PinNote < Base
      description "Pin a note to the top of the notes tab, or unpin it. #{Untrusted::NOTES}"
      endpoint
    end
  end
end
