# frozen_string_literal: true

module MCP
  module Tools
    class ListTaskSeries < Base
      description "List every recurring task series once, oldest first, each with its ID, cadence, whether it is " \
                  "paused, and its current copy: the task's ID, title, status and sprint day. When the copy " \
                  "closes, done or canceled, the next one appears on the next cadence day after today, or after " \
                  "the closed copy's sprint day when that day is still ahead. save_task and capture_task set a " \
                  "cadence with recur"
      endpoint
    end
  end
end
