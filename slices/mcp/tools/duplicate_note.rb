# frozen_string_literal: true

module MCP
  module Tools
    class DuplicateNote < Base
      description "Copy a note with its body and folder under a free title such as \"Plan copy\". The " \
                  "copy carries no tags. #{Untrusted::NOTES}"
      endpoint
    end
  end
end
