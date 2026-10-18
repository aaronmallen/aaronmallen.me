# frozen_string_literal: true

module MCP
  module Tools
    class PauseTaskSeries < Base
      description "Pause one recurring task series by its ID and keep its cadence. Its open copy stays, but " \
                  "closing it makes no new copy until resume_task_series"
      endpoint
    end
  end
end
