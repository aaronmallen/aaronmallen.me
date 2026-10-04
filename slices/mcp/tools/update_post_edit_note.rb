# frozen_string_literal: true

module MCP
  module Tools
    class UpdatePostEditNote < Base
      description "Replace the note on one past edit of a published post, as the admin editor does. " \
                  "read_post lists each note with its ID. The note takes the same checks the editor makes"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
