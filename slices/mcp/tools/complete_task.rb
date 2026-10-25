# frozen_string_literal: true

module MCP
  module Tools
    class CompleteTask < Base
      description "Mark one open or started task done, stamped with the time now. It ends the running work " \
                  "session; hours and minutes, when given, replace the total time worked. " \
                  "It replies with the task's id, label, status, completion time and seconds " \
                  "worked; read_task gives the full record."
      endpoint
    end
  end
end
