# frozen_string_literal: true

module MCP
  module Tools
    class SnoozeAttention < Base
      description "Snooze one row of the needs attention card for seven days, as the admin's snooze button does. " \
                  "Name the row by the kind and record_id list_attention gives it. Snoozing it again moves the end " \
                  "out a week"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
