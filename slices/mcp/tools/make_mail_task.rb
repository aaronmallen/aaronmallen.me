# frozen_string_literal: true

module MCP
  module Tools
    class MakeMailTask < Base
      description "Make a task from one mail thread, as the admin's Make a task dialog does: the task links back " \
                  "to the thread, and the tool archives the thread unless you say otherwise. A thread holds one " \
                  "task, so the tool refuses a second. When Gmail refuses to archive, the task stays and archived " \
                  "comes back false. #{Untrusted::TASK}"
      endpoint
    end
  end
end
