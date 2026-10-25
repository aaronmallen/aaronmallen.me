# frozen_string_literal: true

module MCP
  module Tools
    class SaveTask < Base
      description "Edit one task, as the admin's task editor does. A field you leave out keeps what it has; " \
                  "tags replace the whole set. It replies with the task's id, label, status and the fields you gave; " \
                  "read_task gives the full record. #{Untrusted::TASK}"
      endpoint
    end
  end
end
