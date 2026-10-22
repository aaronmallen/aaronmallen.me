# frozen_string_literal: true

module MCP
  module Tools
    class CreateNote < Base
      description "Write a new private note, in a folder or at the top level. A note title is unique, ignoring " \
                  "case, and [[a title]] in the body links the note of that title. #{Untrusted::NOTES}"
      endpoint
    end
  end
end
