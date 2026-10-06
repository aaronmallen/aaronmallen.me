# frozen_string_literal: true

module MCP
  module Tools
    class CancelTask < Base
      description "Cancel one open or started task, stamped with the time now. It closes without counting as work " \
                  "done, so the activity feed leaves it out. " \
                  "#{Untrusted::TASK}"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
