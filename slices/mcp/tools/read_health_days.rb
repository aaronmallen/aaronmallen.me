# frozen_string_literal: true

module MCP
  module Tools
    class ReadHealthDays < Base
      description "Read the owner's health beside the work, one row per day over a range. Give from and to as " \
                  "YYYY-MM-DD; both days count, at most #{Blog::Helpers::DayWindow::LONGEST} days. Each day gives " \
                  "minutes asleep for the night that ended that morning, bed and wake times, resting heart rate, " \
                  "HRV, steps and active zone minutes, null where the watch sent nothing, and beside them the " \
                  "focus minutes, commits, commits from 22:00 on, tasks done, pull requests opened and merged, " \
                  "journal entries and the first and last activity. The range's workouts come after the days, " \
                  "then 30 day baselines up to to, then four fixed patterns as group averages, each null when a " \
                  "group has under 3 days. They state averages, not causes"
      endpoint scope: Blog::Types::OAuthScope["health"]
    end
  end
end
