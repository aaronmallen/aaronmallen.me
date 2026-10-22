# frozen_string_literal: true

module MCP
  module Tools
    class SaveMailDraft < Base
      description "Save a mail draft to Gmail for the owner to read and send from the admin, or replace one when " \
                  "you give the draft an earlier save answered. A replace writes the whole draft, so give every " \
                  "field again. No tool sends mail"
      endpoint
    end
  end
end
