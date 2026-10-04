# frozen_string_literal: true

module MCP
  module Tools
    class SummarizeActivity < Base
      description "Count the activity feed over a range: every kind in it by kind, the same counts month by " \
                  "month newest first, and per repository the commits with the lines added and deleted. " \
                  "Counts only, so no commit message, journal entry or title comes back. " \
                  "Give from and to as YYYY-MM-DD; both days sit inside the range, which runs at most " \
                  "#{Blog::DayWindow::LONGEST} days. " \
                  "A year answers in one call, so call this first to see where the work sits, then read the " \
                  "months that matter with read_activity, one month at a time, newest first"
      endpoint scope: OAuth::Scope::READ
    end
  end
end
